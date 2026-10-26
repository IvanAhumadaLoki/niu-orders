require "rails_helper"

RSpec.describe DispatchOrderJob do
  let(:store) { create(:restaurant, code: "PROV") }
  let(:order) { create(:order, :delivery, restaurant: store) }
  let(:store_url) { "http://store.test/mock_store/PROV/orders" }

  before do
    # El job usa el despachador real; solo se redirige a una URL de prueba
    # y WebMock simula la respuesta de la tienda.
    allow(StoreDispatcher).to receive(:default_base_url).and_return("http://store.test/mock_store")
  end

  def perform(order_id = order.id)
    described_class.new.perform(order_id)
  end

  describe "#perform cuando la tienda confirma" do
    it "termina sin error" do
      request = stub_request(:post, store_url).to_return(status: 200, body: "{}")

      expect { perform }.not_to raise_error
      expect(request).to have_been_requested.once
    end

    it "deja la orden enviada, con su fecha y un intento registrado" do
      stub_request(:post, store_url).to_return(status: 200, body: "{}")

      perform

      order.reload
      expect(order).to be_dispatch_sent
      expect(order.dispatch_attempts).to eq(1)
      expect(order.dispatched_at).to be_within(5.seconds).of(Time.current)
      expect(order.last_dispatch_error).to be_nil
    end
  end

  describe "#perform cuando la tienda falla" do
    it "lanza un error reintentable si la tienda responde 503" do
      stub_request(:post, store_url).to_return(status: 503, body: "caída")

      expect { perform }.to raise_error(DispatchOrderJob::RetryableDeliveryError, /503/)
    end

    it "deja la orden pendiente, con el intento y el motivo registrados" do
      stub_request(:post, store_url).to_return(status: 503, body: "caída")

      expect { perform }.to raise_error(DispatchOrderJob::RetryableDeliveryError)

      order.reload
      expect(order).to be_dispatch_pending
      expect(order.dispatch_attempts).to eq(1)
      expect(order.last_dispatch_error).to include("503")
    end

    it "lanza un error reintentable si la tienda no responde a tiempo" do
      stub_request(:post, store_url).to_timeout

      expect { perform }.to raise_error(DispatchOrderJob::RetryableDeliveryError)
    end

    it "se recupera cuando la tienda vuelve: acumula intentos y termina enviada" do
      stub_request(:post, store_url).to_return({ status: 503 }, { status: 503 }, { status: 200 })

      2.times { expect { perform }.to raise_error(DispatchOrderJob::RetryableDeliveryError) }
      perform

      order.reload
      expect(order).to be_dispatch_sent
      expect(order.dispatch_attempts).to eq(3)
      expect(order.last_dispatch_error).to be_nil
    end
  end

  describe "#perform cuando la tienda rechaza" do
    it "no reintenta" do
      request = stub_request(:post, store_url).to_return(status: 422, body: "{}")

      expect { perform }.not_to raise_error
      expect(request).to have_been_requested.once
    end

    it "deja la orden en error con el motivo" do
      stub_request(:post, store_url).to_return(status: 422, body: "{}")

      perform

      order.reload
      expect(order).to be_dispatch_error
      expect(order.dispatch_attempts).to eq(1)
      expect(order.last_dispatch_error).to include("422")
    end
  end

  describe "#perform en casos especiales" do
    it "no reenvía una orden que ya fue entregada" do
      order.mark_dispatched!
      request = stub_request(:post, store_url).to_return(status: 200)

      perform

      expect(request).not_to have_been_requested
      expect(order.reload.dispatch_attempts).to eq(0)
    end

    it "descarta el trabajo si la orden ya no existe" do
      expect(StoreDispatcher).not_to receive(:call)

      expect { perform(0) }.not_to raise_error
    end
  end

  describe ".retries_exhausted" do
    it "deja la orden en error con el motivo del último fallo" do
      described_class.retries_exhausted(order.id, StandardError.new("tienda caída"))

      order.reload
      expect(order).to be_dispatch_error
      expect(order.last_dispatch_error).to include("Se agotaron los reintentos", "tienda caída")
    end

    it "no pisa una orden que ya figura como enviada" do
      order.mark_dispatched!

      described_class.retries_exhausted(order.id, StandardError.new("tarde"))

      expect(order.reload).to be_dispatch_sent
    end

    it "ignora una orden que ya no existe" do
      expect { described_class.retries_exhausted(0, StandardError.new("x")) }.not_to raise_error
    end
  end

  describe "configuración de reintentos" do
    it "reintenta una vez por cada espera definida" do
      expect(described_class.get_sidekiq_options["retry"]).to eq(5)
    end

    it "espera más entre cada reintento y repite la última espera al agotar el calendario" do
      delays = (0..4).map { |count| described_class.retry_delay(count) }

      expect(delays).to eq([ 5, 15, 30, 60, 120 ])
      expect(delays).to eq(delays.sort)
      expect(described_class.retry_delay(10)).to eq(120)
    end
  end
end