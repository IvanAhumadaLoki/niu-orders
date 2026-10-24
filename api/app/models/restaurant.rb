# Restaurante (tienda) de la franquicia que recibe y prepara las órdenes.
#
# Se identifica por un `code` corto y único (PROV, LCON, NUNO).
# La asociación con las órdenes se agrega junto con el modelo Order.
class Restaurant < ApplicationRecord
  # Deja el código siempre en mayúsculas y sin espacios en los bordes,
  # de modo que "prov " y "PROV" se traten como el mismo código.
  normalizes :code, with: ->(code) { code.strip.upcase }

  validates :name, presence: true
  validates :code, presence: true,
                   uniqueness: true,
                   format: { with: /\A[A-Z0-9]+\z/, message: "solo admite letras mayúsculas y números" }
end