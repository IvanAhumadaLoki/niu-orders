require "rails_helper"

RSpec.describe StoreDispatcher do
  let(:store) { create(:restaurant, code: "PROV") }
  let(:order) { create(:order, :delivery, restaurant: store) }
  let(:base_url) { "http://store.test/mock_store" }
  let(:store_url) { "#{base_url}/PROV/orders" }

  def dispatch(url = base_url)
    described_class.call(order, base_url: url)
  end

  describe "petición a la tienda" do
    it "envía por POST el JSON de la orden al endpoint de su tienda" do
      expected_body = JSON.parse(OrderSerializer.new(order).as_json.to_json)
      request = stub_request(:post, store_url)
                .with(
                  body: expected_body,
                  headers: {
                    "Content-Type" => "application/json",
                    "X-Idempotency-Key" => "order-#{order.id}"
                  }
                )
                .to_return(status: 200, body: "{}")

      dispatch

      expect(request).to have_been_requested.once
    end

    it "tolera una URL base con barra final" do
      request = stub_request(:post, store_url).to_return(status: 200)

      dispatch("#{base_url}/")

      expect(request).to have_been_requested.once
    end
  end

  describe "clasificación de las respuestas" do
    {
      200 => :delivered, 201 => :delivered, 204 => :delivered,
      408 => :retryable, 429 => :retryable, 500 => :retryable, 503 => :retryable,
      301 => :rejected, 400 => :rejected, 404 => :rejected, 422 => :rejected
    }.each do |status, outcome|
      it "HTTP #{status} se clasifica como #{outcome}" do
        stub_request(:post, store_url).to_return(status: status, body: "")

        result = dispatch

        expect(result.outcome).to eq(outcome)
        expect(result.http_status).to eq(status)
        expect(result.public_send("#{outcome}?")).to be(true)
      end
    end

    it "limita el largo del cuerpo que se incluye en el mensaje" do
      stub_request(:post, store_url).to_return(status: 503, body: "x" * 500)

      result = dispatch

      expect(result.message).to start_with("La tienda respondió 503:")
      expect(result.message.length).to be < 260
    end
  end

  describe "fallos de red" do
    it "trata un timeout como reintentable" do
      stub_request(:post, store_url).to_timeout

      result = dispatch

      expect(result).to be_retryable
      expect(result.http_status).to be_nil
    end

    [ Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, EOFError ].each do |error_class|
      it "trata #{error_class} como reintentable" do
        stub_request(:post, store_url).to_raise(error_class)

        result = dispatch

        expect(result).to be_retryable
        expect(result.message).to include(error_class.name)
      end
    end

    it "no esconde errores de programación" do
      stub_request(:post, store_url).to_raise(ArgumentError)

      expect { dispatch }.to raise_error(ArgumentError)
    end
  end

  describe "precondiciones" do
    it "exige una orden ya guardada" do
      expect { described_class.call(build(:order)) }.to raise_error(ArgumentError, /guardada/)
    end

    it "no modifica la orden: registrar el resultado es tarea de otro componente" do
      stub_request(:post, store_url).to_return(status: 503)

      expect { dispatch }.not_to change { order.reload.attributes }
    end
  end

  describe ".default_base_url" do
    it "usa STORE_BASE_URL cuando está definida" do
      stub_const("ENV", ENV.to_hash.merge("STORE_BASE_URL" => "http://otra.test/tiendas"))

      expect(described_class.default_base_url).to eq("http://otra.test/tiendas")
    end

    it "apunta a la tienda simulada local por defecto" do
      stub_const("ENV", ENV.to_hash.except("STORE_BASE_URL"))

      expect(described_class.default_base_url).to eq("http://localhost:3000/mock_store")
    end
  end
end