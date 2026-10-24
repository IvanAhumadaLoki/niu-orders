# Fábrica de productos para los tests.
# Las secuencias evitan choques con el índice único de `sku`.
# El prefijo TEST- es distinto al de los seeds (SKU-001...SKU-010) para que
# crear productos de prueba nunca choque con el catálogo real cargado.
FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "#{Faker::Food.dish} #{n}" }
    sequence(:sku) { |n| format("TEST-%03d", n) }
    price_clp { Faker::Number.between(from: 1_000, to: 10_000) }
  end
end