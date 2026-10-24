# Crea una orden a partir del payload recibido por la API.
#
# Responsabilidad: traducir el payload JSON (cliente anidado, ítems por
# product_id) a una Order con sus OrderItems y guardarla. No decide montos:
# el precio unitario, el subtotal y el total los calculan los modelos
# (OrderItem y Order) al validar, de modo que cualquier valor que informe el
# cliente se ignora, porque este servicio solo lee las claves conocidas.
#
# Uso:
#   result = OrderCreator.call(params)
#   result.success?  # => true si la orden quedó guardada
#   result.order     # => la orden (persistida o con errores)
#   result.errors    # => errores por campo, listos para devolver como JSON
#
# Guardar la orden y sus ítems ocurre en una sola transacción (autosave de
# Order): o se guardan todos, o no se guarda nada.
class OrderCreator
  # Resultado de la operación. Evita lanzar excepciones para un caso normal
  # (datos inválidos) y le da al llamador una interfaz simple.
  Result = Struct.new(:order, keyword_init: true) do
    def success?
      order.persisted?
    end

    def errors
      order.errors.to_hash
    end
  end

  def self.call(params)
    new(params).call
  end

  # `params` puede ser ActionController::Parameters ya permitido (strong params)
  # o un Hash común, por ejemplo desde un script o un test. Si llegan parámetros
  # sin permitir, `to_h` lanza una excepción: es una protección intencional.
  def initialize(params)
    @data = params.to_h.with_indifferent_access
  end

  def call
    order = build_order
    order.save
    Result.new(order: order)
  end

  private

  attr_reader :data

  # Arma la orden y sus ítems sin guardarlos.
  def build_order
    order = Order.new(
      restaurant_id: data[:restaurant_id],
      order_type: data[:order_type],
      delivery_address: data[:delivery_address],
      customer_name: data.dig(:customer, :name),
      customer_phone: data.dig(:customer, :phone)
    )

    items_data.each do |item|
      order.items.build(product_id: item[:product_id], quantity: item[:quantity])
    end

    order
  end

  # Lista de ítems del payload. Se descarta cualquier elemento que no sea un
  # objeto, para tolerar payloads mal formados (la validación de Order exigirá
  # al menos un ítem y devolverá el 422 correspondiente).
  def items_data
    Array.wrap(data[:items]).select { |item| item.is_a?(Hash) }
  end
end