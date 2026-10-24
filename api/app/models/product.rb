# Producto del catálogo que se puede incluir en una orden.
#
# `price_clp` es el precio vigente. Cada ítem de una orden guardará su propia
# copia del precio al momento de la compra, para no alterar órdenes antiguas.
class Product < ApplicationRecord
  # El SKU se guarda en mayúsculas y sin espacios en los bordes.
  normalizes :sku, with: ->(sku) { sku.strip.upcase }

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  # Entero mayor que cero: el CLP no tiene decimales.
  validates :price_clp, numericality: { only_integer: true, greater_than: 0 }
end