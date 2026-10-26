# Orden de compra recibida por la API y destinada a un restaurante.
#
# Reglas principales:
# - Debe tener al menos un ítem, sin repetir productos.
# - Si es delivery, exige dirección de entrega.
# - El total (`total_clp`) SIEMPRE lo calcula el servidor a partir de los ítems;
#   cualquier valor que llegue desde afuera se sobrescribe antes de validar.
# - Lleva el estado de su despacho a la tienda (ver "Estado del despacho").
class Order < ApplicationRecord
  belongs_to :restaurant

  # `autosave: true` hace que los errores de un ítem se reporten con su campo
  # (por ejemplo "items.quantity" o "items.product") en vez de un genérico
  # "items is invalid", lo que le da al cliente de la API un error accionable.
  has_many :items, class_name: "OrderItem", dependent: :destroy,
                   inverse_of: :order, autosave: true

  # Tipo de pedido. Con `validate: true`, un valor desconocido no lanza una
  # excepción: queda como error de validación, que la API devuelve como 422.
  enum :order_type, { pickup: "pickup", delivery: "delivery" }, validate: true

  # Estado del despacho a la tienda. El prefijo evita choques de nombres
  # (queda `dispatch_pending?`, `dispatch_sent?`, `dispatch_error?` y sus scopes).
  #   pending -> aún no confirmada por la tienda (incluye los reintentos en curso)
  #   sent    -> la tienda confirmó la recepción
  #   error   -> rechazo definitivo o reintentos agotados
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

  # --- Estado del despacho ---------------------------------------------------
  # Los usa DispatchOrderJob para dejar registrado qué pasó con la entrega.

  # Cuenta un intento de entrega. Es un incremento atómico en la base de datos
  # (UPDATE ... SET dispatch_attempts = dispatch_attempts + 1), seguro aunque
  # dos procesos lo hagan a la vez. Se llama ANTES de enviar, para que un
  # intento cuente aunque el proceso muera a mitad de camino.
  def register_dispatch_attempt!
    increment!(:dispatch_attempts, touch: true)
  end

  # Falla transitoria: guarda el motivo, pero la orden sigue pendiente porque
  # todavía se va a reintentar.
  def record_dispatch_failure!(message)
    update_dispatch_state!(last_dispatch_error: message)
  end

  # La tienda confirmó la recepción: se limpia el último error.
  def mark_dispatched!
    update_dispatch_state!(dispatch_status: :sent, dispatched_at: Time.current, last_dispatch_error: nil)
  end

  # Rechazo definitivo o reintentos agotados: no se intentará más.
  def mark_dispatch_error!(message)
    update_dispatch_state!(dispatch_status: :error, last_dispatch_error: message)
  end

  private

  # Guarda SOLO columnas de despacho, sin validaciones. Es a propósito:
  # registrar lo que pasó con la entrega no debe depender de que el resto de la
  # orden pase las reglas actuales, ni recalcular el total (before_validation).
  def update_dispatch_state!(attributes)
    assign_attributes(attributes)
    save!(validate: false)
  end

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