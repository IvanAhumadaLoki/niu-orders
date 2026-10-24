# Fábrica de productos para los tests.
# Las secuencias evitan choques con el índice único de `sku`.
FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "#{Faker::Food.dish} #{n}" }
    sequence(:sku) { |n| format("SKU-%03d", n) }
    price_clp { Faker::Number.between(from: 1_000, to: 10_000) }
  end
end