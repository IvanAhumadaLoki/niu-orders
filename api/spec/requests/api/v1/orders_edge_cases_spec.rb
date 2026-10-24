require "rails_helper"

# Casos borde del endpoint de órdenes: lo que un cliente real podría enviar mal.
# Objetivo: la API siempre responde con un 422 claro (o 201 si el dato es
# tolerable), nunca con un 500.
RSpec.describe "POST /api/v1/orders: casos borde", type: :request do
  include_context "payload de orden"

  describe "datos del cliente" do
    it "normaliza un teléfono con espacios y guiones" do
      post_order(payload.merge(customer: { name: "Ana Pérez", phone: "+56 9 1234-5678" }))

      expect(response).to have_http_status(201)
      expect(response.parsed_body["customer"]["phone"]).to eq("+56912345678")
    end

    it "rechaza un teléfono con letras" do
      post_order(payload.merge(customer: { name: "Ana Pérez", phone: "abc" }))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("customer_phone")
    end

    it "rechaza un nombre formado solo por espacios" do
      post_order(payload.merge(customer: { name: "   ", phone: "+56912345678" }))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("customer_name")
    end

    it "rechaza una dirección formada solo por espacios en un delivery" do
      post_order(payload.merge(delivery_address: "   "))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("delivery_address")
    end
  end

  describe "cantidades y tipos de dato" do
    it "rechaza una cantidad con texto no numérico" do
      post_order(payload.merge(items: [ { product_id: salmon_roll.id, quantity: "abc" } ]))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("items.quantity")
    end

    it "rechaza una cantidad decimal" do
      post_order(payload.merge(items: [ { product_id: salmon_roll.id, quantity: 1.5 } ]))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("items.quantity")
    end

    it "rechaza una cantidad nula" do
      post_order(payload.merge(items: [ { product_id: salmon_roll.id, quantity: nil } ]))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("items.quantity")
    end

    it "rechaza una cantidad negativa sin filtrar errores de campos que el cliente no envió" do
      post_order(payload.merge(items: [ { product_id: salmon_roll.id, quantity: -1 } ]))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("items.quantity")
      # El total es un campo interno: un ítem inválido no debe generar un error de total.
      expect(error_details).not_to have_key("total_clp")
    end

    it "rechaza un ítem sin product_id" do
      post_order(payload.merge(items: [ { quantity: 1 } ]))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("items.product")
    end

    it "acepta IDs y cantidades enviados como texto numérico" do
      as_text = payload.merge(
        restaurant_id: restaurant.id.to_s,
        items: [ { product_id: salmon_roll.id.to_s, quantity: "2" } ]
      )

      post_order(as_text)

      expect(response).to have_http_status(201)
      expect(response.parsed_body["total_clp"]).to eq(17_980)
    end
  end

  describe "forma del payload" do
    it "responde 422 si `items` no es un arreglo" do
      post_order(payload.merge(items: "abc"))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("items")
    end

    it "responde 422 si los elementos de `items` no son objetos" do
      post_order(payload.merge(items: [ 1, 2 ]))

      expect(response).to have_http_status(422)
      expect(error_details).to have_key("items")
    end

    it "responde 422 si `customer` no es un objeto" do
      post_order(payload.merge(customer: "Ana"))

      expect(response).to have_http_status(422)
      expect(error_details).to include("customer_name", "customer_phone")
    end

    it "responde 422 si el cuerpo es un JSON válido pero no un objeto" do
      post "/api/v1/orders", params: "[]", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
    end
  end

  describe "campos que controla el servidor" do
    it "ignora id, fecha de creación y datos de despacho enviados por el cliente" do
      tampered = payload.merge(
        id: 999_999,
        created_at: "2000-01-01T00:00:00Z",
        dispatch_attempts: 5,
        dispatched_at: "2000-01-01T00:00:00Z"
      )

      post_order(tampered)

      body = response.parsed_body
      expect(response).to have_http_status(201)
      expect(body["id"]).not_to eq(999_999)
      expect(body["dispatch_attempts"]).to eq(0)
      expect(Time.zone.parse(body["created_at"])).to be_within(60).of(Time.current)
      expect(Order.find(body["id"]).dispatched_at).to be_nil
    end
  end

  describe "varios productos" do
    it "suma correctamente productos con cantidades distintas" do
      catalog = [ [ 3_290, 3 ], [ 1_990, 2 ], [ 9_990, 1 ] ].map do |price, quantity|
        [ create(:product, price_clp: price), quantity ]
      end
      items = catalog.map { |product, quantity| { product_id: product.id, quantity: quantity } }

      post_order(payload.merge(items: items))

      expect(response).to have_http_status(201)
      # 3.290 x 3 + 1.990 x 2 + 9.990 x 1
      expect(response.parsed_body["total_clp"]).to eq(23_840)
      expect(response.parsed_body["items"].map { |item| item["subtotal_clp"] })
        .to contain_exactly(9_870, 3_980, 9_990)
    end

    it "no guarda nada si uno de los ítems es inválido" do
      items = [ { product_id: salmon_roll.id, quantity: 1 }, { product_id: 0, quantity: 1 } ]

      expect { post_order(payload.merge(items: items)) }
        .not_to change { [ Order.count, OrderItem.count ] }

      expect(response).to have_http_status(422)
    end
  end

  describe "persistencia" do
    it "guarda en la base de datos lo mismo que devuelve la API" do
      post_order(payload)

      order = Order.find(response.parsed_body["id"])

      expect(order).to have_attributes(
        restaurant_id: restaurant.id,
        order_type: "delivery",
        customer_name: "Ana Pérez",
        total_clp: 22_470
      )
      expect(order.items.count).to eq(2)
    end

    it "no deduplica: dos envíos idénticos crean dos órdenes distintas" do
      # Decisión deliberada: la prueba no define una clave de idempotencia,
      # así que cada petición válida es una orden nueva.
      expect { 2.times { post_order(payload) } }.to change(Order, :count).by(2)
    end
  end
end