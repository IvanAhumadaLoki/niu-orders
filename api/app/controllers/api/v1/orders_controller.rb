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
    # Respuestas:
    #   201 -> orden guardada (el despacho a tienda se agrega en commits posteriores)
    #   422 -> datos inválidos, con el detalle de errores por campo
    class OrdersController < ApplicationController
      def create
        order = build_order

        if order.save
          render json: OrderSerializer.new(order).as_json, status: 201
        else
          render json: { errors: order.errors.to_hash }, status: 422
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

      # Traduce el payload JSON a una orden con sus ítems, sin guardarla.
      # El precio, el subtotal y el total los calculan los modelos
      # (Order y OrderItem) al validar.
      def build_order
        data = order_params

        order = Order.new(
          restaurant_id: data[:restaurant_id],
          order_type: data[:order_type],
          delivery_address: data[:delivery_address],
          customer_name: data.dig(:customer, :name),
          customer_phone: data.dig(:customer, :phone)
        )

        Array(data[:items]).each do |item|
          order.items.build(product_id: item[:product_id], quantity: item[:quantity])
        end

        order
      end
    end
  end
end