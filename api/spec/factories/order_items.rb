# Fábrica de ítems. No define `order`: el ítem se agrega a una orden con
# `order.items << build(:order_item)` o `order.items.build(...)`.
FactoryBot.define do
  factory :order_item do
    product
    quantity { 1 }
  end
end