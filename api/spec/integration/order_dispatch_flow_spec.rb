require "rails_helper"

# Flujo completo de una orden: API -> cola -> job -> despachador -> tienda.
#
# A diferencia de los specs unitarios, aquí NADA del camino se reemplaza por un
# doble: se usa la API real, el job real, el despachador HTTP real y el
# controlador real de la tienda simulada.
#
# Dos adaptaciones propias del entorno de pruebas:
#  - La tienda no corre en un servidor aparte: WebMock enruta las llamadas HTTP
#    del despachador directamente al controlador de la tienda, dentro de este
#    mismo proceso (`to_rack`). Se ejecuta el mismo código, sin red.
#  - Sidekiq está en modo "fake" y su motor de reintentos no corre; el ayudante
#    `run_with_retries` lo emula (ver spec/support/dispatch_flow.rb). El motor
#    real se verifica a mano con la tienda caída (ver README).
RSpec.describe "Flujo completo de despacho de una orden", type: :request do
  include_context "payload de orden"
  include DispatchFlowHelpers

  # Restaurante con un código real de la prueba (el del contexto es genérico).
  let(:restaurant) { create(:restaurant, code: "LCON") }
  let(:store_url) { "http://store.test/mock_store/LCON/orders" }

  before do
    allow(StoreDispatcher).to receive(:default_base_url).and_return("http://store.test/mock_store")
    stub_request(:any, %r{\Ahttp://store\.test/}).to_rack(Rails.application)
  end

  # Crea una orden por la API y devuelve su ID.
  def create_order_via_api(body = payload)
    post_order(body)
    expect(response).to have_http_status(201)
    response.parsed_body["id"]
  end

  describe "con la tienda disponible" do
    it "entrega la orden a su tienda y la deja enviada" do
      order_id = create_order_via_api

      # La API responde antes de despachar: la orden nace pendiente.
      expect(Order.find(order_id)).to be_dispatch_pending
      expect(DispatchOrderJob.jobs.size).to eq(1)

      process_enqueued_jobs

      order = Order.find(order_id)
      expect(order).to be_dispatch_sent
      expect(order.dispatch_attempts).to eq(1)
      expect(order.dispatched_at).to be_within(5.seconds).of(Time.current)
      expect(order.last_dispatch_error).to be_nil

      # Lo que recibió la tienda es la orden tal como la guardó la API
      # (8.990 x 2 + 4.490 x 1 = 22.470).
      expect(
        a_request(:post, store_url).with { |request|
          JSON.parse(request.body).values_at("id", "total_clp") == [ order_id, 22_470 ]
        }
      ).to have_been_made.once
    end

    it "envía cada orden a la tienda de su restaurante" do
      providencia = create(:restaurant, code: "PROV")

      create_order_via_api                                                  # va a LCON
      create_order_via_api(payload.merge(restaurant_id: providencia.id))    # va a PROV

      process_enqueued_jobs

      expect(a_request(:post, store_url)).to have_been_made.once
      expect(a_request(:post, "http://store.test/mock_store/PROV/orders")).to have_been_made.once
      expect(Order.pluck(:dispatch_status)).to all(eq("sent"))
    end

    it "no duplica el pedido si el mismo trabajo se ejecuta dos veces" do
      order_id = create_order_via_api
      process_enqueued_jobs

      expect { DispatchOrderJob.new.perform(order_id) }.not_to raise_error

      expect(a_request(:post, store_url)).to have_been_made.once
      expect(Order.find(order_id).dispatch_attempts).to eq(1)
    end
  end

  describe "con la tienda caída" do
    it "reintenta y se recupera cuando la tienda vuelve" do
      order_id = create_order_via_api

      with_store_failure_rate(1) do
        2.times do
          expect { DispatchOrderJob.new.perform(order_id) }
            .to raise_error(DispatchOrderJob::RetryableDeliveryError, /503/)
        end
      end

      order = Order.find(order_id)
      expect(order).to be_dispatch_pending
      expect(order.dispatch_attempts).to eq(2)
      expect(order.last_dispatch_error).to include("503")

      # La tienda vuelve a funcionar: el siguiente intento entrega la orden.
      DispatchOrderJob.new.perform(order_id)

      order.reload
      expect(order).to be_dispatch_sent
      expect(order.dispatch_attempts).to eq(3)
      expect(order.last_dispatch_error).to be_nil
      expect(a_request(:post, store_url)).to have_been_made.times(3)
    end

    it "deja la orden en error cuando se agotan los reintentos" do
      order_id = create_order_via_api

      with_store_failure_rate(1) { run_with_retries(order_id) }

      total_attempts = DispatchOrderJob::RETRY_DELAYS.size + 1
      order = Order.find(order_id)
      expect(order).to be_dispatch_error
      expect(order.dispatch_attempts).to eq(total_attempts)
      expect(order.last_dispatch_error).to include("Se agotaron los reintentos", "503")
      expect(a_request(:post, store_url)).to have_been_made.times(total_attempts)
    end
  end

  describe "con una tienda que da un rechazo definitivo" do
    # Se simula apuntando a una ruta que la tienda no tiene: responde 404,
    # un rechazo que reintentar no arreglaría.
    before do
      allow(StoreDispatcher).to receive(:default_base_url).and_return("http://store.test/otra_ruta")
    end

    it "no reintenta y deja la orden en error" do
      order_id = create_order_via_api

      process_enqueued_jobs

      order = Order.find(order_id)
      expect(order).to be_dispatch_error
      expect(order.dispatch_attempts).to eq(1)
      expect(order.last_dispatch_error).to include("404")
      expect(a_request(:post, "http://store.test/otra_ruta/LCON/orders")).to have_been_made.once
    end
  end
end