require "rails_helper"
require_relative "../../scripts/simulate_orders"

# Verifica el simulador contra la API real, sin servidor: las llamadas HTTP del
# script se enrutan por WebMock directamente a la aplicación, dentro del
# proceso de test. Así se comprueba que lo que el script genera (órdenes
# válidas e inválidas) realmente se comporta como el script espera.
RSpec.describe OrderSimulator, type: :request do
  let(:api_url) { "http://api.test" }

  before do
    # Los seeds crean los 3 restaurantes y los 10 productos con los IDs del dataset.
    allow($stdout).to receive(:puts)
    Rails.application.load_seed
  end

  def plan(count: 24, invalid: 0, seed: 1)
    OrderSimulator::Generator.new(Random.new(seed)).plan(count: count, invalid: invalid)
  end

  # Enruta las llamadas HTTP del simulador a la API real.
  def route_to_api
    stub_request(:any, %r{\Ahttp://api\.test/}).to_rack(Rails.application)
  end

  def run_simulator(entries)
    out = StringIO.new
    code = OrderSimulator::Runner.new(OrderSimulator::Client.new(api_url), entries, out: out).run
    [ code, out.string ]
  end

  describe "órdenes generadas" do
    it "las válidas son aceptadas y su total coincide con el dataset" do
      plan(count: 12).each do |entry|
        post "/api/v1/orders", params: entry.payload, as: :json

        expect(response).to have_http_status(201), "orden #{entry.number}: respondió #{response.status}"
        expect(response.parsed_body["total_clp"]).to eq(entry.expected_total)
        expect(response.parsed_body.dig("restaurant", "code")).to eq(entry.store_code)
      end
    end

    it "cubren las 3 tiendas y ambos tipos de pedido" do
      payloads = plan(count: 24).map(&:payload)

      expect(payloads.map { |payload| payload[:restaurant_id] }.uniq).to contain_exactly(1, 2, 3)
      expect(payloads.map { |payload| payload[:order_type] }.uniq).to contain_exactly("pickup", "delivery")
    end

    it "cada escenario inválido es rechazado con 422 y el error esperado" do
      total = OrderSimulator::INVALID_SCENARIOS.size
      entries = plan(count: total, invalid: total)

      expect(entries.map(&:description)).to match_array(OrderSimulator::INVALID_SCENARIOS.map { |s| s[:name] })

      entries.each do |entry|
        expect { post "/api/v1/orders", params: entry.payload, as: :json }.not_to change(Order, :count)

        expect(response).to have_http_status(422), "#{entry.description}: respondió #{response.status}"
        expect(response.parsed_body.dig("error", "details")).to have_key(entry.expected_error_key)
      end
    end

    it "mezcla exactamente la cantidad pedida de órdenes inválidas" do
      entries = plan(count: 10, invalid: 3)

      expect(entries.size).to eq(10)
      expect(entries.count { |entry| entry.kind == :invalid }).to eq(3)
    end

    it "es reproducible con la misma semilla y distinto con otra" do
      expect(plan(seed: 7).map(&:payload)).to eq(plan(seed: 7).map(&:payload))
      expect(plan(seed: 7).map(&:payload)).not_to eq(plan(seed: 8).map(&:payload))
    end
  end

  describe OrderSimulator::Client do
    let(:client) { described_class.new(api_url) }
    let(:endpoint) { "http://api.test/api/v1/orders" }

    it "devuelve el estado y el cuerpo JSON de la respuesta" do
      stub_request(:post, endpoint).to_return(status: 201, body: { id: 5, total_clp: 8_990 }.to_json)

      response = client.create_order({ restaurant_id: 1 })

      expect(response.status).to eq(201)
      expect(response.body).to include("id" => 5, "total_clp" => 8_990)
      expect(response.error).to be_nil
    end

    it "informa un fallo de red en vez de lanzar una excepción" do
      stub_request(:post, endpoint).to_raise(Errno::ECONNREFUSED)

      response = client.create_order({ restaurant_id: 1 })

      expect(response.status).to be_nil
      expect(response.error).to include("Errno::ECONNREFUSED")
    end
  end

  describe OrderSimulator::Runner do
    it "termina con código 0 y un resumen cuando todo sale como se esperaba" do
      route_to_api

      code, output = run_simulator(plan(count: 10, invalid: 3))

      expect(code).to eq(0)
      expect(output).to include("Resumen", "Rechazadas (422) ......... 3")
      expect(output).not_to include("FALLA")
      expect(Order.count).to eq(7)
    end

    it "termina con código 1 si la API responde algo distinto de lo esperado" do
      # Una API que acepta todo, incluso lo inválido, y con un total equivocado.
      stub_request(:post, "http://api.test/api/v1/orders")
        .to_return(status: 201, body: { id: 1, total_clp: 1, restaurant: { code: "XXXX" } }.to_json)

      code, output = run_simulator(plan(count: 4, invalid: 2))

      expect(code).to eq(1)
      expect(output).to include("FALLA", "la API aceptó una orden inválida", "total distinto")
    end

    it "se detiene con código 2 y un mensaje claro si la API no está disponible" do
      request = stub_request(:post, "http://api.test/api/v1/orders").to_raise(Errno::ECONNREFUSED)

      code, output = run_simulator(plan(count: 10))

      expect(code).to eq(2)
      expect(output).to include("docker compose up -d")
      expect(request).to have_been_requested.times(3)
    end
  end
end