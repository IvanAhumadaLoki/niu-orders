# Orden de compra recibida por la API y destinada a un restaurante.
#
# Reglas principales:
# - Debe tener al menos un ítem, sin repetir productos.
# - Si es delivery, exige dirección de entrega.
# - El total (`total_clp`) SIEMPRE lo calcula el servidor a partir de los ítems;
#   cualquier valor que llegue desde afuera se sobrescribe antes de validar.
# - El estado de despacho a tienda arranca en "pending" (ver enum más abajo).
class Order < ApplicationRecord
  belongs_to :restaurant
  has_many :items, class_name: "OrderItem", dependent: :destroy, inverse_of: :order

  # Tipo de pedido. Con `validate: true`, un valor desconocido no lanza una
  # excepción: queda como error de validación, que la API devuelve como 422.
  enum :order_type, { pickup: "pickup", delivery: "delivery" }, validate: true

  # Estado del despacho a la tienda. El prefijo evita choques de nombres
  # (queda `dispatch_pending?`, `dispatch_sent?`, `dispatch_error?` y sus scopes).
  enum :dispatch_status, { pending: "pending", sent: "sent", error: "error" },
       prefix: :dispatch, validate: true

  # Limpieza de datos de entrada antes de validar.
  normalizes :customer_name, with: ->(name) { name.strip }
  normalizes :customer_phone, with: ->(phone) { phone.gsub(/[\s-]/, "") }
  normalizes :delivery_address, with: ->(address) { address.strip }

  validates :customer_name, presence: true
  # Teléfono con prefijo "+" opcional y entre 8 y 15 dígitos (ej: +56912345678).
  validates :customer_phone, presence: true,
                             format: { with: /\A\+?\d{8,15}\z/, allow_blank: true }
  validates :delivery_address, presence: true, if: :delivery?
  validates :total_clp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :dispatch_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :must_have_items
  validate :items_must_not_repeat_products

  # Corre antes de las validaciones, incluidas las de los ítems.
  before_validation :calculate_total

  private

  # Recalcula los montos de cada ítem y suma el total de la orden.
  # Se piden los montos a cada ítem de forma explícita porque las validaciones
  # de los hijos corren después de este callback del padre.
  def calculate_total
    items.each(&:calculate_amounts)
    self.total_clp = items.map { |item| item.subtotal_clp.to_i }.sum
  end

  def must_have_items
    errors.add(:items, "debe incluir al menos un producto") if items.empty?
  end

  def items_must_not_repeat_products
    products = items.filter_map(&:product)
    errors.add(:items, "no puede repetir un mismo producto") if products.uniq.size != products.size
  end
end