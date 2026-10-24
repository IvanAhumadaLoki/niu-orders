require "rails_helper"

# Verifica que los datos iniciales coincidan con el dataset de la prueba y que
# el script sea seguro de ejecutar más de una vez.
RSpec.describe "db/seeds" do
  before do
    # Silencia el mensaje final del seed para no ensuciar la salida de RSpec.
    allow($stdout).to receive(:puts)
  end

  def run_seeds
    Rails.application.load_seed
  end

  it "crea los 3 restaurantes con los IDs y códigos de la prueba" do
    run_seeds

    expect(Restaurant.order(:id).pluck(:id, :code)).to eq(
      [[1, "PROV"], [2, "LCON"], [3, "NUNO"]]
    )
  end

  it "crea los 10 productos con sus precios en CLP" do
    run_seeds

    expect(Product.count).to eq(10)
    expect(Product.find(1)).to have_attributes(name: "Niu Roll Salmón", sku: "SKU-001", price_clp: 8_990)
    expect(Product.find(10)).to have_attributes(name: "Agua Mineral 500 ml", price_clp: 1_590)
  end

  it "hace que el payload de referencia apunte a los datos correctos" do
    run_seeds

    expect(Restaurant.find(2).code).to eq("LCON")
    expect(Product.find(5).name).to eq("Gyozas de Pollo x5")
  end

  it "es idempotente: ejecutarlo dos veces no duplica registros" do
    run_seeds
    run_seeds

    expect(Restaurant.count).to eq(3)
    expect(Product.count).to eq(10)
  end

  it "deja la secuencia de IDs lista para nuevos registros" do
    run_seeds

    # Si la secuencia no se hubiera reiniciado, el nuevo producto intentaría
    # usar un ID ya ocupado por los seeds y fallaría.
    product = create(:product)

    expect(product.id).to be > 10
  end
end