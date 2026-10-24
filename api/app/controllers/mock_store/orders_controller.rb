module MockStore
  # Tienda simulada: recibe las órdenes que despacha la API central.
  #
  # Es un reemplazo para el sistema real de cada restaurante, pensado para
  # desarrollo y pruebas. Una URL por tienda:
  #
  #   POST /mock_store/:store_code/orders      (store_code = PROV, LCON, NUNO)
  #
  # Qué espera recibir (contrato con el despachador de la API):
  #   id, restaurant.code, order_type, customer.name, customer.phone,
  #   total_clp, items (al menos uno) y delivery_address si es delivery.
  # Es el mismo JSON que produce OrderSerializer.
  #
  # Respuestas:
  #   200 -> orden recibida
  #   404 -> la tienda no existe
  #   422 -> payload incompleto, o dirigido a otra tienda
  #   503 -> tienda caída (fallo simulado, ver más abajo)
  #
  # Simulación de fallos, para probar los reintentos del despacho:
  #   - Header `X-Mock-Store-Behavior: fail` fuerza un 503; `ok` fuerza un éxito.
  #   - Sin header, la variable de entorno MOCK_STORE_FAILURE_RATE (0.0 a 1.0)
  #     define la probabilidad de un 503. Por defecto es 0: nunca falla.
  #
  # Simplificación: la tienda consulta la tabla de restaurantes de la API para
  # saber qué códigos existen. Una tienda real tendría su propio sistema.
  class OrdersController < ApplicationController
    ORDER_TYPES = %w[pickup delivery].freeze

    def create
      return render_store_unavailable if outage?

      store = Restaurant.find_by(code: params[:store_code].to_s.strip.upcase)
      return render_store_not_found unless store

      errors = payload_errors
      return render_validation_error(errors) if errors.any?

      # Evita que una orden de una sucursal termine en otra.
      return render_store_mismatch(store) unless payload_store_code == store.code

      Rails.logger.info(
        "[MockStore #{store.code}] Orden ##{payload[:id]} recibida: " \
        "#{payload[:order_type]}, total #{payload[:total_clp]} CLP, #{payload[:items].size} ítem(s)"
      )

      render json: {
        status: "received",
        store_code: store.code,
        order_id: payload[:id],
        received_at: Time.current.iso8601
      }, status: 200
    end

    private

    # El payload se lee completo y se valida a mano: esta tienda no usa strong
    # params porque no guarda nada ni crea modelos con estos datos.
    def payload
      @payload ||= params.to_unsafe_h
    end

    # El header manda sobre la variable de entorno.
    def outage?
      case request.headers["X-Mock-Store-Behavior"]
      when "fail" then true
      when "ok" then false
      else rand < failure_rate
      end
    end

    def failure_rate
      ENV.fetch("MOCK_STORE_FAILURE_RATE", "0").to_f.clamp(0.0, 1.0)
    end

    # Valor de un sub-objeto del payload, tolerando que no sea un objeto
    # (por ejemplo, `"customer": "Ana"`) sin lanzar una excepción.
    def hash_value(key, subkey)
      value = payload[key]
      value[subkey] if value.is_a?(Hash)
    end

    def payload_store_code
      hash_value(:restaurant, :code).to_s.strip.upcase
    end

    def payload_errors
      errors = {}
      errors[:id] = [ "es obligatorio" ] if payload[:id].blank?
      errors[:restaurant] = [ "debe incluir el código de la tienda" ] if hash_value(:restaurant, :code).blank?
      errors[:order_type] = [ "debe ser pickup o delivery" ] unless ORDER_TYPES.include?(payload[:order_type])

      if hash_value(:customer, :name).blank? || hash_value(:customer, :phone).blank?
        errors[:customer] = [ "debe incluir nombre y teléfono" ]
      end

      errors[:total_clp] = [ "debe ser un entero mayor o igual a 0" ] unless valid_total?
      errors[:items] = [ "debe incluir al menos un producto" ] unless valid_items?

      if payload[:order_type] == "delivery" && payload[:delivery_address].blank?
        errors[:delivery_address] = [ "es obligatoria en un delivery" ]
      end

      errors
    end

    def valid_total?
      total = payload[:total_clp]
      total.is_a?(Integer) && total >= 0
    end

    def valid_items?
      items = payload[:items]
      items.is_a?(Array) && items.any?
    end

    def render_store_unavailable
      render_error(code: "store_unavailable", message: "La tienda no está disponible (fallo simulado)", status: 503)
    end

    def render_store_not_found
      render_error(code: "store_not_found", message: "No existe la tienda #{params[:store_code]}", status: 404)
    end

    def render_store_mismatch(store)
      render_error(
        code: "store_mismatch",
        message: "La orden está dirigida a #{payload_store_code}, no a #{store.code}",
        status: 422
      )
    end
  end
end