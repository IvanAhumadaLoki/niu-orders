require "rails_helper"

RSpec.describe OrderCreator do
  let(:restaurant) { create(:restaurant) }
  let(:salmon_roll) { create(:product, price_clp: 8_990) }
  let(:gyozas) { create(:product, price_clp: 4_490) }

  let(:params) do
    {
      restaurant_id: restaurant.id,
      order_type: "delivery",
      customer: { name: "Ana Pérez", phone: "+56912345678" },
      delivery_address: "Av. Providencia 1234, Santiago",
      items: [
        { product_id: salmon_roll.id, quantity: 2 },
        { product_id: gyozas.id, quantity: 1 }
      ]
    }
  end

  describe ".call con datos válidos" do
    it "guarda la orden y sus ítems" do
      result = nil

      expect { result = described_class.call(params) }
        .to change(Order, :count).by(1)
        .and change(OrderItem, :count).by(2)

      expect(result).to be_success
      expect(result.order).to be_persisted
    end

    it "calcula el total en el servidor y congela los precios" do
      order = described_class.call(params).order

      # 8.990 x 2 + 4.490 x 1
      expect(order.total_clp).to eq(22_470)
      expect(order.items.map(&:unit_price_clp)).to contain_exactly(8_990, 4_490)
    end

    it "ignora el total, el precio y el estado informados por el cliente" do
      tampered = params.merge(
        total_clp: 1,
        dispatch_status: "sent",
        items: [ { product_id: salmon_roll.id, quantity: 2, unit_price_clp: 1 } ]
      )

      order = described_class.call(tampered).order

      expect(order.total_clp).to eq(17_980)
      expect(order.items.first.unit_price_clp).to eq(8_990)
      expect(order).to be_dispatch_pending
    end

    it "acepta claves de texto, como las que llegan desde JSON" do
      result = described_class.call(params.deep_stringify_keys)

      expect(result).to be_success
    end
  end

  describe ".call con datos inválidos" do
    it "no guarda nada y expone los errores por campo" do
      result = nil

      expect { result = described_class.call(params.except(:delivery_address)) }
        .not_to change(Order, :count)

      expect(result).not_to be_success
      expect(result.errors).to have_key(:delivery_address)
    end

    it "no deja nada a medias si un ítem es inválido" do
      invalid_items = [
        { product_id: salmon_roll.id, quantity: 2 },
        { product_id: gyozas.id, quantity: 0 }
      ]

      expect { described_class.call(params.merge(items: invalid_items)) }
        .not_to change { [ Order.count, OrderItem.count ] }
    end

    it "devuelve error si no vienen ítems" do
      result = described_class.call(params.except(:items))

      expect(result).not_to be_success
      expect(result.errors).to have_key(:items)
    end
  end
end