require "net/http"
require "json"

# Envía una orden ya guardada a la tienda (restaurante) que debe prepararla.
#
# Responsabilidad: hacer UN intento de entrega por HTTP y clasificar el
# resultado. No guarda nada en la base de datos ni reintenta: de eso se
# encargan el job de Sidekiq y el registro de estado de los commits siguientes.
#
# Destino: POST {STORE_BASE_URL}/{código de la tienda}/orders
# (por ejemplo http://api:3000/mock_store/PROV/orders). Cada orden va a la
# tienda de su restaurante. El cuerpo es el mismo JSON que devuelve la API
# (OrderSerializer), así la tienda recibe un formato conocido.
#
# Uso:
#   result = StoreDispatcher.call(order)
#   result.delivered?  # la tienda confirmó la recepción (2xx)
#   result.retryable?  # falla transitoria: conviene reintentar
#   result.rejected?   # rechazo definitivo: reintentar no ayudaría
#   result.message     # descripción legible del resultado
#
# Cómo se clasifica:
#   2xx                                -> delivered
#   5xx, 408, 429, timeout, error red  -> retryable
#   cualquier otra respuesta (4xx, 3xx) -> rejected
#
# Se envía el header X-Idempotency-Key con un valor fijo por orden
# ("order-<id>"), idéntico en cada reintento. Una tienda real puede usarlo
# para ignorar duplicados si la primera entrega sí llegó pero la respuesta se
# perdió. La tienda simulada lo ignora.
class StoreDispatcher
  OPEN_TIMEOUT = 3  # segundos máximos para establecer la conexión
  READ_TIMEOUT = 5  # segundos máximos esperando la respuesta

  # Códigos 4xx que son transitorios: la tienda pide esperar y volver a intentar.
  RETRYABLE_STATUSES = [ 408, 429 ].freeze

  # Errores de red que se consideran transitorios. Timeout::Error cubre los
  # timeouts de conexión y lectura de Net::HTTP; SystemCallError cubre
  # "conexión rechazada", "conexión reiniciada", etc.
  # Un error de programación (ArgumentError, NoMethodError...) NO está aquí:
  # debe fallar de forma visible en vez de reintentarse en silencio.
  NETWORK_ERRORS = [
    Timeout::Error, SocketError, SystemCallError, IOError,
    Net::ProtocolError, Net::HTTPBadResponse
  ].freeze

  # Resultado de un intento de entrega.
  #   outcome:     :delivered, :retryable o :rejected
  #   http_status: código HTTP de la tienda, o nil si no hubo respuesta
  #   message:     descripción legible (se guardará como último error)
  Result = Struct.new(:outcome, :http_status, :message, keyword_init: true) do
    def delivered?
      outcome == :delivered
    end

    def retryable?
      outcome == :retryable
    end

    def rejected?
      outcome == :rejected
    end
  end

  def self.call(order, base_url: default_base_url)
    new(order, base_url: base_url).call
  end

  # Se lee al momento de usarla (no al cargar la clase) para que el entorno
  # pueda cambiarla sin reiniciar. Por defecto apunta a la tienda simulada.
  def self.default_base_url
    ENV.fetch("STORE_BASE_URL", "http://localhost:3000/mock_store")
  end

  def initialize(order, base_url: self.class.default_base_url)
    raise ArgumentError, "La orden debe estar guardada antes de despacharla" unless order.persisted?

    @order = order
    @base_url = base_url
  end

  def call
    classify(post_to_store)
  rescue *NETWORK_ERRORS => e
    Result.new(outcome: :retryable, message: "Fallo de red: #{e.class}: #{e.message}")
  end

  private

  attr_reader :order, :base_url

  # Un único POST con el JSON de la orden.
  def post_to_store
    uri = store_uri

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["X-Idempotency-Key"] = "order-#{order.id}"
    request.body = OrderSerializer.new(order).as_json.to_json

    Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    ) { |http| http.request(request) }
  end

  # La URL de cada tienda se arma con el código de su restaurante.
  # Una URL base mal escrita lanza URI::InvalidURIError a propósito: es un
  # error de configuración, no una falla de entrega, y no se reintenta.
  def store_uri
    URI.parse("#{base_url.chomp('/')}/#{order.restaurant.code}/orders")
  end

  def classify(response)
    status = response.code.to_i
    body = response.body.to_s.squish.truncate(200)

    if (200..299).cover?(status)
      Result.new(outcome: :delivered, http_status: status,
                 message: "Orden recibida por la tienda (HTTP #{status})")
    elsif status >= 500 || RETRYABLE_STATUSES.include?(status)
      Result.new(outcome: :retryable, http_status: status,
                 message: "La tienda respondió #{status}: #{body}")
    else
      Result.new(outcome: :rejected, http_status: status,
                 message: "La tienda rechazó la orden con #{status}: #{body}")
    end
  end
end