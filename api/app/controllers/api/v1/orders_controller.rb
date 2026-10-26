module Api
  module V1
    # Órdenes: las crean los canales digitales y las consulta el dashboard.
    #
    # El controlador solo se ocupa de HTTP: filtrar parámetros, delegar el
    # trabajo a un servicio (OrderCreator, OrderSearch) y elegir el código de
    # respuesta. Los errores usan el formato estándar (ver ErrorResponder).
    class OrdersController < ApplicationController
      # GET /api/v1/orders
      # Listado paginado, de la más reciente a la más antigua. Filtros opcionales:
      # dispatch_status, restaurant_id, order_type (ver OrderSearch).
      #   200 -> { "data": [ resumen de orden ], "meta": { page, per_page, total_count, total_pages } }
      #   422 -> algún parámetro es inválido
      def index
        result = OrderSearch.call(index_params)

        if result.success?
          render json: {
            data: result.orders.map { |order| OrderSummarySerializer.new(order).as_json },
            meta: result.meta
          }
        else
          render_validation_error(result.errors)
        end
      end

      # GET /api/v1/orders/:id
      # Detalle completo: cliente, dirección, productos y estado de despacho.
      #   200 -> orden completa
      #   404 -> no existe una orden con ese ID
      def show
        order = Order.includes(:restaurant, items: :product).find_by(id: params[:id])
        return render_order_not_found unless order

        render json: OrderSerializer.new(order).as_json
      end

      # POST /api/v1/orders
      # Payload esperado (ver README para ejemplos completos):
      #   {
      #     "restaurant_id": 2,
      #     "order_type": "delivery",
      #     "customer": { "name": "Ana Pérez", "phone": "+56912345678" },
      #     "delivery_address": "Av. Providencia 1234, Santiago",
      #     "items": [ { "product_id": 1, "quantity": 2 } ]
      #   }
      #   201 -> orden guardada; su despacho a la tienda queda encolado
      #   400 -> JSON mal formado (lo responde JsonBodyGuard)
      #   422 -> datos inválidos, con el detalle por campo en `error.details`
      def create
        result = OrderCreator.call(order_params)

        if result.success?
          render json: OrderSerializer.new(result.order).as_json, status: 201
        else
          render_validation_error(result.errors)
        end
      end

      private

      # Strong params de la creación: solo se aceptan estas claves. Todo lo demás
      # se descarta, en particular `total_clp`, `dispatch_status` y
      # `unit_price_clp`, que el servidor define por su cuenta y nunca debe
      # tomar del cliente.
      def order_params
        params.permit(
          :restaurant_id, :order_type, :delivery_address,
          customer: %i[name phone],
          items: %i[product_id quantity]
        )
      end

      # Strong params del listado: paginación y filtros.
      def index_params
        params.permit(:page, :per_page, :dispatch_status, :restaurant_id, :order_type)
      end

      def render_order_not_found
        render_error(code: "not_found", message: "No existe la orden #{params[:id]}", status: 404)
      end
    end
  end
end