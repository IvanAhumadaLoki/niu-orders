module Api
  module V1
    # Recibe órdenes desde los canales digitales.
    #
    # Payload esperado (ver README para ejemplos completos):
    #   {
    #     "restaurant_id": 2,
    #     "order_type": "delivery",
    #     "customer": { "name": "Ana Pérez", "phone": "+56912345678" },
    #     "delivery_address": "Av. Providencia 1234, Santiago",
    #     "items": [ { "product_id": 1, "quantity": 2 } ]
    #   }
    #
    # El controlador solo se ocupa de HTTP: filtrar parámetros, delegar la
    # creación a OrderCreator y elegir el código de respuesta.
    #
    # Respuestas:
    #   201 -> orden guardada (el despacho a tienda se agrega en commits posteriores)
    #   422 -> datos inválidos, con el detalle de errores por campo
    class OrdersController < ApplicationController
      def create
        result = OrderCreator.call(order_params)

        if result.success?
          render json: OrderSerializer.new(result.order).as_json, status: 201
        else
          render json: { errors: result.errors }, status: 422
        end
      end

      private

      # Strong params: solo se aceptan estas claves. Todo lo demás se descarta,
      # en particular `total_clp`, `dispatch_status` y `unit_price_clp`, que
      # el servidor define por su cuenta y nunca debe tomar del cliente.
      def order_params
        params.permit(
          :restaurant_id, :order_type, :delivery_address,
          customer: %i[name phone],
          items: %i[product_id quantity]
        )
      end
    end
  end
end