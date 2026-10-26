require "rails_helper"

# Estado del despacho a la tienda: los métodos que usa DispatchOrderJob para
# dejar registrado qué pasó con cada orden.
RSpec.describe Order, "estado de despacho", type: :model do
  let(:order) { create(:order) }

  describe "#register_dispatch_attempt!" do
    it "suma un intento" do
      order.register_dispatch_attempt!

      expect(order.reload.dispatch_attempts).to eq(1)
    end

    it "acumula los intentos" do
      3.times { order.register_dispatch_attempt! }

      expect(order.reload.dispatch_attempts).to eq(3)
    end
  end

  describe "#record_dispatch_failure!" do
    it "guarda el motivo y deja la orden pendiente, porque aún se reintentará" do
      order.record_dispatch_failure!("La tienda respondió 503")

      order.reload
      expect(order).to be_dispatch_pending
      expect(order.last_dispatch_error).to eq("La tienda respondió 503")
    end
  end

  describe "#mark_dispatched!" do
    it "marca la orden como enviada, registra la fecha y limpia el último error" do
      order.record_dispatch_failure!("La tienda respondió 503")

      order.mark_dispatched!

      order.reload
      expect(order).to be_dispatch_sent
      expect(order.dispatched_at).to be_within(5.seconds).of(Time.current)
      expect(order.last_dispatch_error).to be_nil
    end
  end

  describe "#mark_dispatch_error!" do
    it "marca la orden en error con el motivo" do
      order.mark_dispatch_error!("La tienda rechazó la orden con 422")

      order.reload
      expect(order).to be_dispatch_error
      expect(order.last_dispatch_error).to eq("La tienda rechazó la orden con 422")
    end
  end

  it "registra el estado aunque la orden tenga datos que hoy no pasarían la validación" do
    # Simula una orden antigua con un dato inválido, escrito directo en la base.
    order.update_column(:customer_phone, "abc")

    expect { order.mark_dispatch_error!("falló") }.not_to raise_error
    expect(order.reload).to be_dispatch_error
  end
end