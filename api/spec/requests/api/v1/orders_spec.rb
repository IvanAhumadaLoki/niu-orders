require "rails_helper"

RSpec.describe "POST /api/v1/orders", type: :request do
  let(:restaurant) { create(:restaurant) }
  let(:salmon_roll) { create(:product, price_clp: 8_990) }
  let(:gyozas) { create(:product, price_clp: 4_490) }

  # Payload equivalente al de referencia de la prueba.
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

  describe "con un payload válido" do
    it "responde 201 y guarda la orden con sus ítems" do
      expect { post_order(payload) }
        .to change(Order, :count).by(1)
        .and change(OrderItem, :count).by(2)

      expect(response).to have_http_status(201)
    end

    it "devuelve la orden con el total calculado y el despacho pendiente" do
      post_order(payload)

      expect(response.parsed_body).to include(
        "order_type" => "delivery",
        # 8.990 x 2 + 4.490 x 1
        "total_clp" => 22_470,
        "dispatch_status" => "pending",
        "delivery_address" => "Av. Providencia 1234, Santiago"
      )
      expect(response.parsed_body["customer"]).to eq("name" => "Ana Pérez", "phone" => "+56912345678")
      expect(response.parsed_body["items"].size).to eq(2)
    end

    it "acepta un pedido de retiro sin dirección" do
      post_order(payload.except(:delivery_address).merge(order_type: "pickup"))

      expect(response).to have_http_status(201)
      expect(response.parsed_body["order_type"]).to eq("pickup")
    end

    it "ignora el total, el precio y el estado que informe el cliente" do
      tampered = payload.merge(
        total_clp: 1,
        dispatch_status: "sent",
        items: [ { product_id: salmon_roll.id, quantity: 2, unit_price_clp: 1 } ]
      )

      post_order(tampered)

      expect(response).to have_http_status(201)
      expect(response.parsed_body).to include("total_clp" => 17_980, "dispatch_status" => "pending")
      expect(response.parsed_body["items"].first["unit_price_clp"]).to eq(8_990)
    end
  end

  describe "con datos inválidos" do
    it "responde 422 si es delivery y no trae dirección" do
      expect { post_order(payload.except(:delivery_address)) }.not_to change(Order, :count)

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to have_key("delivery_address")
    end

    it "responde 422 si no trae ítems" do
      post_order(payload.merge(items: []))

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to have_key("items")
    end

    it "responde 422 si el restaurante no existe" do
      post_order(payload.merge(restaurant_id: 0))

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to have_key("restaurant")
    end

    it "responde 422 si algún producto no existe" do
      post_order(payload.merge(items: [ { product_id: 0, quantity: 1 } ]))

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to have_key("items.product")
    end

    it "responde 422 si el tipo de pedido es desconocido" do
      post_order(payload.merge(order_type: "drone"))

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to have_key("order_type")
    end

    it "responde 422 si falta el cliente" do
      post_order(payload.except(:customer))

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to include("customer_name", "customer_phone")
    end

    it "responde 422 si la cantidad no es positiva" do
      post_order(payload.merge(items: [ { product_id: salmon_roll.id, quantity: 0 } ]))

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to have_key("items.quantity")
    end

    it "responde 422 si repite un producto" do
      repeated = [ { product_id: gyozas.id, quantity: 1 }, { product_id: gyozas.id, quantity: 2 } ]

      post_order(payload.merge(items: repeated))

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to have_key("items")
    end
  end
end