require "rails_helper"

RSpec.describe Restaurant, type: :model do
  describe "asociaciones" do
    it { is_expected.to have_many(:orders).dependent(:restrict_with_error) }
  end

  describe "validaciones" do
    subject { build(:restaurant) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }

    it "rechaza un código con espacios o símbolos" do
      restaurant = build(:restaurant, code: "PR-OV")

      expect(restaurant).not_to be_valid
      expect(restaurant.errors[:code]).to be_present
    end

    it "rechaza un código repetido, sin importar mayúsculas" do
      create(:restaurant, code: "PROV")
      duplicate = build(:restaurant, code: "prov")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to be_present
    end
  end

  describe "normalización" do
    it "guarda el código en mayúsculas y sin espacios en los bordes" do
      restaurant = build(:restaurant, code: " prov ")

      expect(restaurant.code).to eq("PROV")
    end
  end
end