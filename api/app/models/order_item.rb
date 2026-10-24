# Línea de una orden: un producto con su cantidad.
#
# El precio unitario NO se acepta desde afuera: al crear el ítem se copia el
# precio vigente del producto y queda congelado. Así el total de una orden
# histórica no cambia aunque el catálogo se actualice después.
class OrderItem < ApplicationRecord
  belongs_to :order, inverse_of: :items
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  before_validation :calculate_amounts

  # Fija el precio unitario (solo al crear) y calcula el subtotal.
  # Es público porque Order lo invoca antes de sumar su total.
  def calculate_amounts
    return unless product && quantity.is_a?(Integer)

    self.unit_price_clp = product.price_clp if new_record?
    self.subtotal_clp = unit_price_clp * quantity
  end
end