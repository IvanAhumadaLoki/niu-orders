#!/usr/bin/env ruby
# frozen_string_literal: true

# Simulador de órdenes: genera pedidos con el dataset de productos de la prueba
# y los envía a la API, como lo harían los canales digitales reales.
#
# Se comporta como un cliente externo: usa solo la biblioteca estándar de Ruby
# y NO carga Rails, así que puede correr en cualquier máquina con Ruby.
#
# Uso (dentro del contenedor de la API, que ya tiene Ruby):
#   docker compose exec api ruby scripts/simulate_orders.rb
#   docker compose exec api ruby scripts/simulate_orders.rb --count 30 --invalid 5
#   docker compose exec api ruby scripts/simulate_orders.rb --seed 42
#   docker compose exec api ruby scripts/simulate_orders.rb --help
#
# Qué genera:
#   - Órdenes con 1 a 4 productos distintos y cantidades de 1 a 5.
#   - Las 3 tiendas y los 2 tipos de pedido (pickup y delivery), en rotación,
#     de modo que con 6 órdenes o más aparecen las 6 combinaciones.
#   - Algunas órdenes inválidas a propósito (--invalid), para mostrar cómo la
#     API las rechaza con 422.
#
# Qué verifica de cada respuesta:
#   - Orden válida:   201, y que el total que devuelve la API coincida con el
#                     total calculado aquí a partir del dataset.
#   - Orden inválida: 422, con el error del campo esperado.
#   - Cualquier otra respuesta se marca como FALLA.
#
# Código de salida: 0 si todo salió como se esperaba, 1 si hubo resultados
# inesperados, 2 si la API no es alcanzable o las opciones son incorrectas.
#
# Cada ejecución imprime su semilla: con --seed se repite la misma secuencia.

require "json"
require "net/http"
require "optparse"
require "uri"

module OrderSimulator
  # --- Dataset de la prueba ---------------------------------------------------
  # Debe coincidir con los seeds de la API (api/db/seeds.rb). Precios en CLP.

  Product = Struct.new(:id, :name, :sku, :price_clp)
  Store = Struct.new(:id, :code, :name)

  PRODUCTS = [
    Product.new(1, "Niu Roll Salmón", "SKU-001", 8_990),
    Product.new(2, "California Ebi", "SKU-002", 7_490),
    Product.new(3, "Avocado Roll", "SKU-003", 6_990),
    Product.new(4, "Nigiri Salmón x2", "SKU-004", 3_990),
    Product.new(5, "Gyozas de Pollo x5", "SKU-005", 4_490),
    Product.new(6, "Edamame", "SKU-006", 3_290),
    Product.new(7, "Bowl Salmón Teriyaki", "SKU-007", 9_990),
    Product.new(8, "Bowl Pollo Teriyaki", "SKU-008", 8_990),
    Product.new(9, "Bebida 350 ml", "SKU-009", 1_990),
    Product.new(10, "Agua Mineral 500 ml", "SKU-010", 1_590)
  ].freeze

  STORES = [
    Store.new(1, "PROV", "Niu Foods Providencia"),
    Store.new(2, "LCON", "Niu Foods Las Condes"),
    Store.new(3, "NUNO", "Niu Foods Ñuñoa")
  ].freeze

  ORDER_TYPES = %w[pickup delivery].freeze

  # Datos de apoyo para inventar clientes y direcciones.
  FIRST_NAMES = %w[Ana Camila Diego Felipe Javiera Matías Valentina Sebastián Constanza Nicolás].freeze
  LAST_NAMES = %w[Pérez González Muñoz Rojas Díaz Soto Contreras Silva Martínez Sepúlveda].freeze
  STREETS = [
    "Av. Providencia", "Av. Apoquindo", "Av. Irarrázaval", "Av. Vitacura",
    "Calle Monjitas", "Av. Italia", "Av. Los Leones", "Av. Pedro de Valdivia"
  ].freeze

  # --- Escenarios de órdenes inválidas -----------------------------------------
  # Cada uno toma una orden válida y la rompe de una forma concreta.
  #   name:      descripción para el reporte
  #   error_key: campo que debe aparecer en `error.details` de la respuesta 422
  #   mutate:    función que transforma el payload válido en uno inválido
  INVALID_SCENARIOS = [
    { name: "delivery sin dirección", error_key: "delivery_address",
      mutate: ->(payload) { payload.merge(order_type: "delivery").except(:delivery_address) } },
    { name: "restaurante inexistente", error_key: "restaurant",
      mutate: ->(payload) { payload.merge(restaurant_id: 999) } },
    { name: "producto inexistente", error_key: "items.product",
      mutate: ->(payload) { payload.merge(items: [ { product_id: 999, quantity: 1 } ]) } },
    { name: "cantidad cero", error_key: "items.quantity",
      mutate: ->(payload) { payload.merge(items: [ payload[:items].first.merge(quantity: 0) ]) } },
    { name: "orden sin productos", error_key: "items",
      mutate: ->(payload) { payload.merge(items: []) } },
    { name: "producto repetido", error_key: "items",
      mutate: ->(payload) { payload.merge(items: [ payload[:items].first ] * 2) } },
    { name: "teléfono inválido", error_key: "customer_phone",
      mutate: ->(payload) { payload.merge(customer: payload[:customer].merge(phone: "abc")) } },
    { name: "tipo de pedido desconocido", error_key: "order_type",
      mutate: ->(payload) { payload.merge(order_type: "drone") } }
  ].freeze

  # Una orden del plan de envío, con lo que se espera de la API.
  #   kind:                :valid o :invalid
  #   expected_total:      total en CLP calculado con el dataset (solo válidas)
  #   expected_error_key:  campo que debe fallar (solo inválidas)
  Entry = Struct.new(
    :number, :kind, :payload, :description, :expected_total, :expected_error_key, :store_code,
    keyword_init: true
  )

  # Formatea un monto en pesos chilenos: 22470 -> "$ 22.470".
  def self.clp(amount)
    "$ #{amount.to_i.to_s.reverse.scan(/\d{1,3}/).join('.').reverse}"
  end

  # --- Generador ---------------------------------------------------------------
  # Arma el plan de órdenes. Todo el azar sale de un generador con semilla, así
  # que la misma semilla produce siempre las mismas órdenes.
  class Generator
    def initialize(rng)
      @rng = rng
    end

    # Devuelve `count` entradas, `invalid` de ellas inválidas y en posiciones
    # al azar. Los escenarios inválidos se reparten sin repetirse hasta agotarlos.
    def plan(count:, invalid:)
      invalid_positions = (0...count).to_a.sample(invalid, random: @rng)
      scenarios = INVALID_SCENARIOS.shuffle(random: @rng).cycle

      (0...count).map do |index|
        invalid_positions.include?(index) ? invalid_entry(index, scenarios.next) : valid_entry(index)
      end
    end

    private

    # La tienda y el tipo de pedido rotan según la posición (3 tiendas y 2 tipos
    # son coprimos: en 6 órdenes aparecen las 6 combinaciones). Lo demás es azar.
    def valid_entry(index)
      store = STORES[index % STORES.size]
      order_type = ORDER_TYPES[index % ORDER_TYPES.size]
      lines = random_lines

      payload = {
        restaurant_id: store.id,
        order_type: order_type,
        customer: { name: random_name, phone: random_phone },
        items: lines.map { |product, quantity| { product_id: product.id, quantity: quantity } }
      }
      payload[:delivery_address] = random_address if order_type == "delivery"

      Entry.new(
        number: index + 1,
        kind: :valid,
        payload: payload,
        description: "#{store.code} #{order_type}",
        # Total calculado aquí, de forma independiente a la API, para contrastarlo.
        expected_total: lines.sum { |product, quantity| product.price_clp * quantity },
        store_code: store.code
      )
    end

    def invalid_entry(index, scenario)
      base = valid_entry(index)

      Entry.new(
        number: base.number,
        kind: :invalid,
        payload: scenario[:mutate].call(base.payload),
        description: scenario[:name],
        expected_error_key: scenario[:error_key],
        store_code: base.store_code
      )
    end

    # De 1 a 4 productos distintos, cada uno con una cantidad de 1 a 5.
    def random_lines
      PRODUCTS.sample(@rng.rand(1..4), random: @rng).map { |product| [ product, @rng.rand(1..5) ] }
    end

    def random_name
      "#{FIRST_NAMES.sample(random: @rng)} #{LAST_NAMES.sample(random: @rng)}"
    end

    # Celular chileno: +569 seguido de 8 dígitos.
    def random_phone
      format("+569%08d", @rng.rand(10**8))
    end

    def random_address
      "#{STREETS.sample(random: @rng)} #{@rng.rand(100..9999)}, Santiago"
    end
  end

  # --- Cliente HTTP --------------------------------------------------------------
  class Client
    # Errores de red: no hay respuesta de la API (caída, timeout, DNS...).
    NETWORK_ERRORS = [
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
      SocketError, Net::OpenTimeout, Net::ReadTimeout, EOFError
    ].freeze

    # status: código HTTP (nil si no hubo respuesta)
    # body:   JSON de la respuesta como Hash (vacío si no era un objeto JSON)
    # error:  descripción del fallo de red, si lo hubo
    Response = Struct.new(:status, :body, :error, keyword_init: true)

    def initialize(base_url)
      @uri = URI.join("#{base_url.chomp('/')}/", "api/v1/orders")
    end

    # POST /api/v1/orders. No lanza excepciones por fallos de red: los devuelve
    # en `error`, para que el simulador siga con la siguiente orden.
    def create_order(payload)
      request = Net::HTTP::Post.new(@uri, "Content-Type" => "application/json", "Accept" => "application/json")
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(
        @uri.host, @uri.port,
        use_ssl: @uri.scheme == "https", open_timeout: 3, read_timeout: 10
      ) { |http| http.request(request) }

      Response.new(status: response.code.to_i, body: parse_json(response.body))
    rescue *NETWORK_ERRORS => e
      Response.new(body: {}, error: "#{e.class}: #{e.message}")
    end

    private

    def parse_json(text)
      parsed = JSON.parse(text.to_s)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end
  end

  # --- Ejecución y reporte -------------------------------------------------------
  # Envía cada entrada, compara la respuesta con lo esperado e imprime el resultado.
  class Runner
    # Tras tantos fallos de conexión seguidos, se asume que la API no está y se detiene.
    MAX_CONSECUTIVE_NETWORK_ERRORS = 3

    # verdict: :ok (salió como se esperaba) o :unexpected
    Outcome = Struct.new(:entry, :response, :verdict, :detail, keyword_init: true)

    def initialize(client, entries, delay: 0.0, out: $stdout)
      @client = client
      @entries = entries
      @delay = delay
      @out = out
      @outcomes = []
    end

    # Devuelve el código de salida: 0 todo esperado, 1 hubo resultados
    # inesperados, 2 la API no es alcanzable.
    def run
      network_failures = 0

      @entries.each do |entry|
        response = @client.create_order(entry.payload)
        outcome = evaluate(entry, response)
        @outcomes << outcome
        print_outcome(outcome)

        network_failures = response.error ? network_failures + 1 : 0
        return abort_run if network_failures >= MAX_CONSECUTIVE_NETWORK_ERRORS

        sleep(@delay) if @delay.positive?
      end

      print_summary
      @outcomes.any? { |outcome| outcome.verdict == :unexpected } ? 1 : 0
    end

    private

    # Compara la respuesta con lo que se esperaba de esa entrada.
    def evaluate(entry, response)
      if response.error
        return build_outcome(entry, response, :unexpected, "sin respuesta: #{response.error}")
      end

      verdict, detail = entry.kind == :valid ? check_valid(entry, response) : check_invalid(entry, response)
      build_outcome(entry, response, verdict, detail)
    end

    def build_outcome(entry, response, verdict, detail)
      Outcome.new(entry: entry, response: response, verdict: verdict, detail: detail)
    end

    # Una orden válida debe dar 201, con el total y la tienda correctos.
    def check_valid(entry, response)
      unless response.status == 201
        return [ :unexpected, "se esperaba 201 y la API respondió #{describe(response)}" ]
      end

      problems = []
      received_total = response.body["total_clp"]
      if received_total != entry.expected_total
        problems << "total distinto: esperado #{OrderSimulator.clp(entry.expected_total)}, " \
                    "recibido #{OrderSimulator.clp(received_total)}"
      end

      received_store = response.body.dig("restaurant", "code")
      problems << "tienda distinta: esperada #{entry.store_code}, recibida #{received_store}" if received_store != entry.store_code

      problems.empty? ? [ :ok, nil ] : [ :unexpected, problems.join("; ") ]
    end

    # Una orden inválida debe dar 422, con el campo esperado entre los errores.
    def check_invalid(entry, response)
      if response.status == 201
        return [ :unexpected, "la API aceptó una orden inválida (#{describe(response)})" ]
      end

      unless response.status == 422
        return [ :unexpected, "se esperaba 422 y la API respondió #{describe(response)}" ]
      end

      keys = error_keys(response)
      return [ :ok, nil ] if keys.include?(entry.expected_error_key)

      [ :unexpected, "422 sin el error esperado '#{entry.expected_error_key}' (llegó: #{keys.join(', ')})" ]
    end

    # Campos con error en una respuesta 422: claves de `error.details`.
    def error_keys(response)
      error = response.body["error"]
      details = error.is_a?(Hash) ? error["details"] : nil
      details.is_a?(Hash) ? details.keys : []
    end

    def describe(response)
      return "sin respuesta (#{response.error})" if response.error

      case response.status
      when 201 then "201 orden ##{response.body['id']} total #{OrderSimulator.clp(response.body['total_clp'])}"
      when 422 then "422 #{error_keys(response).join(', ')}"
      else
        error = response.body["error"]
        "HTTP #{response.status} #{error['code'] if error.is_a?(Hash)}".strip
      end
    end

    def print_outcome(outcome)
      entry = outcome.entry

      label =
        if entry.kind == :valid
          format("%-4s %-8s %d ítem(s)", entry.store_code, entry.payload[:order_type], entry.payload[:items].size)
        else
          "INVÁLIDA: #{entry.description}"
        end

      line = format("[%2d/%d] %s -> %s  %s", entry.number, @entries.size, label,
                    describe(outcome.response), outcome.verdict == :ok ? "OK" : "FALLA")
      line += " (#{outcome.detail})" if outcome.detail
      @out.puts line
    end

    def abort_run
      @out.puts
      @out.puts "No se pudo conectar con la API tras #{MAX_CONSECUTIVE_NETWORK_ERRORS} intentos seguidos. " \
                "¿Está levantada? Prueba: docker compose up -d"
      2
    end

    def print_summary
      accepted = @outcomes.select { |outcome| outcome.response.status == 201 }
      rejected = @outcomes.select { |outcome| outcome.response.status == 422 }
      unexpected = @outcomes.select { |outcome| outcome.verdict == :unexpected }

      @out.puts
      @out.puts "Resumen"
      @out.puts "  Órdenes enviadas ......... #{@outcomes.size}"
      @out.puts "  Aceptadas (201) .......... #{accepted.size}  (monto total #{OrderSimulator.clp(accepted.sum { |o| o.response.body['total_clp'].to_i })})"
      @out.puts "  Rechazadas (422) ......... #{rejected.size}"
      @out.puts "  Resultados inesperados ... #{unexpected.size}"
      @out.puts "  Aceptadas por tienda ..... #{count_by(accepted) { |o| o.entry.store_code }}"
      @out.puts "  Aceptadas por tipo ....... #{count_by(accepted) { |o| o.entry.payload[:order_type] }}"

      return if unexpected.empty?

      @out.puts
      @out.puts "Detalle de los resultados inesperados:"
      unexpected.each { |outcome| @out.puts "  ##{outcome.entry.number} #{outcome.entry.description}: #{outcome.detail}" }
    end

    def count_by(outcomes, &block)
      counts = outcomes.group_by(&block).transform_values(&:size)
      counts.empty? ? "-" : counts.sort.map { |key, total| "#{key} #{total}" }.join(", ")
    end
  end

  # --- Línea de comandos ----------------------------------------------------------
  def self.parse_options(argv)
    options = {
      url: ENV.fetch("API_URL", "http://localhost:3000"),
      count: 20,
      invalid: 3,
      seed: Random.new_seed % 100_000,
      delay: 0.0
    }

    OptionParser.new do |parser|
      parser.banner = "Uso: ruby scripts/simulate_orders.rb [opciones]"
      parser.on("--url URL", "URL base de la API (por defecto #{options[:url]}; también API_URL)") { |v| options[:url] = v }
      parser.on("--count N", Integer, "Total de órdenes a enviar (por defecto 20)") { |v| options[:count] = v }
      parser.on("--invalid N", Integer, "Cuántas de ellas son inválidas a propósito (por defecto 3)") { |v| options[:invalid] = v }
      parser.on("--seed N", Integer, "Semilla del azar; la misma semilla repite las mismas órdenes") { |v| options[:seed] = v }
      parser.on("--delay SEGUNDOS", Float, "Pausa entre órdenes (por defecto 0)") { |v| options[:delay] = v }
      parser.on("-h", "--help", "Muestra esta ayuda") do
        puts parser
        exit 0
      end
    end.parse!(argv)

    fail_with("--count debe ser mayor que 0") unless options[:count].positive?
    fail_with("--invalid debe estar entre 0 y --count (#{options[:count]})") unless (0..options[:count]).cover?(options[:invalid])
    fail_with("--delay no puede ser negativo") if options[:delay].negative?

    options
  rescue OptionParser::ParseError => e
    fail_with(e.message)
  end

  def self.fail_with(message)
    warn "Error: #{message}"
    exit 2
  end

  def self.main(argv)
    options = parse_options(argv)
    entries = Generator.new(Random.new(options[:seed])).plan(count: options[:count], invalid: options[:invalid])

    puts "Simulador de órdenes -> #{options[:url]}"
    puts "  #{options[:count]} órdenes (#{options[:invalid]} inválidas a propósito) | semilla #{options[:seed]} " \
         "(repite con --seed #{options[:seed]})"
    puts

    exit Runner.new(Client.new(options[:url]), entries, delay: options[:delay]).run
  end
end

# Solo se ejecuta al invocar el archivo directamente: así los specs pueden
# cargarlo (require) sin disparar el envío de órdenes.
OrderSimulator.main(ARGV) if $PROGRAM_NAME == __FILE__