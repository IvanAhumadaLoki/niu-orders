require "rails_helper"

RSpec.describe Order, type: :model do
  describe "asociaciones" do
    it { is_expected.to belong_to(:restaurant) }
    it { is_expected.to have_many(:items).class_name("OrderItem").dependent(:destroy) }
  end

  describe "validaciones" do
    subject { build(:order) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:customer_name) }
    it { is_expected.to validate_presence_of(:customer_phone) }

    it "rechaza un teléfono con formato inválido" do
      order = build(:order, customer_phone: "abc")

      expect(order).not_to be_valid
      expect(order.errors[:customer_phone]).to be_present
    end

    it "rechaza un tipo de pedido desconocido sin lanzar excepción" do
      order = build(:order, order_type: "drone")

      expect(order).not_to be_valid
      expect(order.errors[:order_type]).to be_present
    end

    it "rechaza un tipo de pedido vacío" do
      order = build(:order, order_type: nil)

      expect(order).not_to be_valid
      expect(order.errors[:order_type]).to be_present
    end

    it "exige dirección de entrega si es delivery" do
      order = build(:order, :delivery, delivery_address: nil)

      expect(order).not_to be_valid
      expect(order.errors[:delivery_address]).to be_present
    end

    it "no exige dirección de entrega si es pickup" do
      order = build(:order, order_type: "pickup", delivery_address: nil)

      expect(order).to be_valid
    end

    it "exige al menos un ítem" do
      order = build(:order, items_count: 0)

      expect(order).not_to be_valid
      expect(order.errors[:items]).to be_present
    end

    it "rechaza un mismo producto repetido" do
      product = create(:product)
      order = build(:order, items_count: 0)
      2.times { order.items.build(product: product, quantity: 1) }

      expect(order).not_to be_valid
      expect(order.errors[:items]).to be_present
    end

    it "rechaza un ítem con cantidad cero" do
      order = build(:order, items_count: 0)
      order.items.build(product: create(:product), quantity: 0)

      expect(order).not_to be_valid
    end
  end

  describe "normalización" do
    it "deja el teléfono sin espacios ni guiones" do
      order = build(:order, customer_phone: " +56 9 1234-5678 ")

      expect(order.customer_phone).to eq("+56912345678")
    end
  end

  describe "total" do
    let(:salmon_roll) { create(:product, price_clp: 8_990) }
    let(:gyozas) { create(:product, price_clp: 4_490) }

    it "se calcula en el servidor e ignora el total informado" do
      order = build(:order, items_count: 0, total_clp: 1)
      order.items.build(product: salmon_roll, quantity: 2)
      order.items.build(product: gyozas, quantity: 1)

      order.valid?

      # 8.990 x 2 + 4.490 x 1
      expect(order.total_clp).to eq(22_470)
    end

    it "no cambia si el precio del producto se modifica después" do
      order = build(:order, items_count: 0)
      order.items.build(product: salmon_roll, quantity: 2)
      order.save!

      salmon_roll.update!(price_clp: 12_000)
      order.reload

      expect(order.total_clp).to eq(17_980)
      expect(order.items.first.unit_price_clp).to eq(8_990)
    end
  end

  describe "despacho" do
    it "nace pendiente y sin intentos" do
      order = create(:order)

      expect(order).to be_dispatch_pending
      expect(order.dispatch_attempts).to eq(0)
    end
  end
end