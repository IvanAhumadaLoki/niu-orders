require "rails_helper"

RSpec.describe "POST /mock_store/:store_code/orders", type: :request do
  let!(:store) { create(:restaurant, code: "PROV") }
  let(:order) { create(:order, :delivery, restaurant: store) }
  # Se usa el mismo serializador de la API: así este spec es también una prueba
  # de contrato. Si el despachador envía este JSON, la tienda lo acepta.
  let(:payload) { OrderSerializer.new(order).as_json }
  let(:path) { "/mock_store/PROV/orders" }

  def post_to_store(body, headers: {})
    post path, params: body, as: :json, headers: headers
  end

  # Fija la probabilidad de fallo solo durante el bloque, y deja el entorno
  # como estaba (asignar nil a ENV elimina la variable).
  def with_failure_rate(rate)
    original = ENV["MOCK_STORE_FAILURE_RATE"]
    ENV["MOCK_STORE_FAILURE_RATE"] = rate.to_s
    yield
  ensure
    ENV["MOCK_STORE_FAILURE_RATE"] = original
  end

  describe "recepción exitosa" do
    it "acepta la orden tal como la serializa la API" do
      post_to_store(payload)

      expect(response).to have_http_status(200)
      expect(response.parsed_body).to include(
        "status" => "received",
        "store_code" => "PROV",
        "order_id" => order.id
      )
    end

    context "con un pedido de retiro" do
      let(:order) { create(:order, restaurant: store) }

      it "acepta la orden sin dirección de entrega" do
        post_to_store(payload)

        expect(response).to have_http_status(200)
      end
    end
  end

  describe "tienda de destino" do
    it "responde 404 si la tienda no existe" do
      post "/mock_store/ZZZZ/orders", params: payload, as: :json

      expect(response).to have_http_status(404)
      expect(response.parsed_body.dig("error", "code")).to eq("store_not_found")
    end

    it "rechaza con 422 una orden dirigida a otra tienda" do
      create(:restaurant, code: "LCON")

      post "/mock_store/LCON/orders", params: payload, as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("error", "code")).to eq("store_mismatch")
    end
  end

  describe "payload inválido" do
    it "responde 422 e indica qué campos faltan" do
      post_to_store({})

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("error", "details")).to include(
        "id", "restaurant", "order_type", "customer", "total_clp", "items"
      )
    end

    it "exige dirección si la orden es delivery" do
      post_to_store(payload.merge(delivery_address: nil))

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("error", "details")).to have_key("delivery_address")
    end

    it "exige al menos un producto" do
      post_to_store(payload.merge(items: []))

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("error", "details")).to have_key("items")
    end
  end

  describe "fallos simulados" do
    it "responde 503 si el header pide un fallo" do
      post_to_store(payload, headers: { "X-Mock-Store-Behavior" => "fail" })

      expect(response).to have_http_status(503)
      expect(response.parsed_body.dig("error", "code")).to eq("store_unavailable")
    end

    it "responde 503 si la probabilidad de fallo es 1" do
      with_failure_rate(1) { post_to_store(payload) }

      expect(response).to have_http_status(503)
    end

    it "responde 200 si la probabilidad de fallo es 0" do
      with_failure_rate(0) { post_to_store(payload) }

      expect(response).to have_http_status(200)
    end

    it "deja que el header `ok` gane sobre la probabilidad de fallo" do
      with_failure_rate(1) do
        post_to_store(payload, headers: { "X-Mock-Store-Behavior" => "ok" })
      end

      expect(response).to have_http_status(200)
    end
  end
end