require "rails_helper"

RSpec.describe Product, type: :model do
  describe "validaciones" do
    subject { build(:product) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:sku) }
    # El precio debe ser un entero estrictamente mayor que cero.
    it { is_expected.to validate_numericality_of(:price_clp).only_integer.is_greater_than(0) }

    it "rechaza un SKU repetido, sin importar mayúsculas" do
      create(:product, sku: "SKU-001")
      duplicate = build(:product, sku: "sku-001")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sku]).to be_present
    end
  end

  describe "normalización" do
    it "guarda el SKU en mayúsculas y sin espacios en los bordes" do
      product = build(:product, sku: " sku-001 ")

      expect(product.sku).to eq("SKU-001")
    end
  end
end