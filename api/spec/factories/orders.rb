# Fábrica de órdenes para los tests.
# Por defecto crea una orden de retiro válida con un ítem.
#   build(:order, items_count: 0)  -> orden sin ítems (para probar la validación)
#   build(:order, :delivery)       -> orden con dirección de entrega
FactoryBot.define do
  factory :order do
    restaurant
    order_type { "pickup" }
    customer_name { Faker::Name.name }
    customer_phone { "+56912345678" }

    transient do
      items_count { 1 }
    end

    after(:build) do |order, evaluator|
      evaluator.items_count.times { order.items << build(:order_item) }
    end

    trait :delivery do
      order_type { "delivery" }
      delivery_address { "Av. Providencia 1234, Santiago" }
    end
  end
end