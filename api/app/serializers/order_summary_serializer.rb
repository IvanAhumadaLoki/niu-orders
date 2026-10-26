# Resumen de una orden para el listado del dashboard.
#
# Incluye lo necesario para una fila de tabla (tienda, tipo, monto, fecha y
# estado de despacho) y deja fuera lo pesado: cliente, dirección y detalle de
# productos, que se piden con GET /api/v1/orders/:id (ver OrderSerializer).
#
# Espera que la orden llegue con `restaurant` e `items` precargados
# (ver OrderSearch); si no, cada fila haría consultas adicionales.
class OrderSummarySerializer
  def initialize(order)
    @order = order
  end

  def as_json
    {
      id: @order.id,
      restaurant: {
        id: @order.restaurant.id,
        code: @order.restaurant.code,
        name: @order.restaurant.name
      },
      order_type: @order.order_type,
      total_clp: @order.total_clp,
      dispatch_status: @order.dispatch_status,
      dispatch_attempts: @order.dispatch_attempts,
      last_dispatch_error: @order.last_dispatch_error,
      # `size` usa los ítems ya precargados: no hace una consulta por orden.
      items_count: @order.items.size,
      created_at: @order.created_at.iso8601
    }
  end
end