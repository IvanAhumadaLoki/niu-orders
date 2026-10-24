# Fábrica de restaurantes para los tests.
# Las secuencias evitan choques con el índice único de `code`.
FactoryBot.define do
  factory :restaurant do
    sequence(:name) { |n| "Niu Foods #{Faker::Address.city} #{n}" }
    sequence(:code) { |n| "TST#{n}" }
  end
end