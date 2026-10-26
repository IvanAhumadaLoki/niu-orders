require "rails_helper"

RSpec.describe "GET /api/v1/orders/:id", type: :request do
  let(:order) { create(:order, :delivery) }

  it "devuelve la orden completa, con cliente, dirección y productos" do
    get "/api/v1/orders/#{order.id}"

    expect(response).to have_http_status(200)

    body = response.parsed_body
    item = order.items.first

    expect(body).to include(
      "id" => order.id,
      "order_type" => "delivery",
      "total_clp" => order.total_clp,
      "dispatch_status" => "pending",
      "delivery_address" => "Av. Providencia 1234, Santiago"
    )
    expect(body["customer"]).to eq("name" => order.customer_name, "phone" => "+56912345678")
    expect(body["items"]).to eq(
      [
        {
          "product_id" => item.product_id,
          "name" => item.product.name,
          "sku" => item.product.sku,
          "quantity" => 1,
          "unit_price_clp" => item.unit_price_clp,
          "subtotal_clp" => item.subtotal_clp
        }
      ]
    )
  end

  it "muestra el estado de despacho cuando la entrega falló" do
    order.register_dispatch_attempt!
    order.mark_dispatch_error!("Se agotaron los reintentos")

    get "/api/v1/orders/#{order.id}"

    expect(response.parsed_body).to include(
      "dispatch_status" => "error",
      "dispatch_attempts" => 1,
      "last_dispatch_error" => "Se agotaron los reintentos"
    )
  end

  it "responde 404 con el formato estándar si la orden no existe" do
    get "/api/v1/orders/0"

    expect(response).to have_http_status(404)
    expect(response.parsed_body["error"]).to include("code" => "not_found")
  end

  it "responde 404 si el identificador no es numérico" do
    get "/api/v1/orders/abc"

    expect(response).to have_http_status(404)
    expect(response.parsed_body["error"]).to include("code" => "not_found")
  end
end