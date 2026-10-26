# Convierte una Order en el JSON que expone la API.
# Centralizar el formato aquí permite reutilizarlo en el listado y en el
# detalle del dashboard sin duplicar código. También es el cuerpo que el
# despachador envía a la tienda.
class OrderSerializer
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
      customer: {
        name: @order.customer_name,
        phone: @order.customer_phone
      },
      delivery_address: @order.delivery_address,
      total_clp: @order.total_clp,
      dispatch_status: @order.dispatch_status,
      dispatch_attempts: @order.dispatch_attempts,
      dispatched_at: @order.dispatched_at&.iso8601,
      last_dispatch_error: @order.last_dispatch_error,
      created_at: @order.created_at.iso8601,
      items: @order.items.map { |item| item_json(item) }
    }
  end

  private

  def item_json(item)
    {
      product_id: item.product_id,
      name: item.product.name,
      sku: item.product.sku,
      quantity: item.quantity,
      unit_price_clp: item.unit_price_clp,
      subtotal_clp: item.subtotal_clp
    }
  end
end