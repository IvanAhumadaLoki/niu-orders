require "rails_helper"

RSpec.describe OrderItem, type: :model do
  describe "asociaciones" do
    it { is_expected.to belong_to(:order) }
    it { is_expected.to belong_to(:product) }
  end

  describe "validaciones" do
    subject { build(:order).items.first }

    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
  end

  describe "#calculate_amounts" do
    it "toma el precio del producto e ignora el precio informado" do
      product = build(:product, price_clp: 4_490)
      item = OrderItem.new(product: product, quantity: 3, unit_price_clp: 1)

      item.calculate_amounts

      expect(item.unit_price_clp).to eq(4_490)
      expect(item.subtotal_clp).to eq(13_470)
    end
  end
end