require "rails_helper"

RSpec.describe OrderSerializer do
  let(:order) { create(:order, :delivery) }

  it "expone el estado de despacho de una orden recién creada" do
    json = described_class.new(order).as_json

    expect(json).to include(
      dispatch_status: "pending",
      dispatch_attempts: 0,
      dispatched_at: nil,
      last_dispatch_error: nil
    )
  end

  it "expone la fecha de envío y el último error cuando existen" do
    order.register_dispatch_attempt!
    order.mark_dispatched!

    json = described_class.new(order).as_json

    expect(json).to include(dispatch_status: "sent", dispatch_attempts: 1, last_dispatch_error: nil)
    expect(Time.zone.parse(json[:dispatched_at])).to be_within(5.seconds).of(Time.current)
  end
end