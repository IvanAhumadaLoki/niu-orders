# Contexto compartido para los specs del endpoint de órdenes.
# Define un payload válido equivalente al de referencia de la prueba y dos
# ayudantes, para no repetirlos en cada archivo:
#   post_order(body)  -> envía el cuerpo como JSON a POST /api/v1/orders
#   error_details     -> `error.details` de la respuesta (errores por campo)
#
# Uso:  include_context "payload de orden"
RSpec.shared_context "payload de orden" do
  let(:restaurant) { create(:restaurant) }
  let(:salmon_roll) { create(:product, price_clp: 8_990) }
  let(:gyozas) { create(:product, price_clp: 4_490) }

  let(:payload) do
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

  def post_order(body)
    post "/api/v1/orders", params: body, as: :json
  end

  def error_details
    response.parsed_body.dig("error", "details")
  end
end