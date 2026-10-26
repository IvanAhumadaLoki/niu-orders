require "rails_helper"

RSpec.describe OrderSummarySerializer do
  it "resume la orden sin incluir cliente ni detalle de productos" do
    order = create(:order, :delivery)

    json = described_class.new(order).as_json

    expect(json.keys).to contain_exactly(
      :id, :restaurant, :order_type, :total_clp, :dispatch_status,
      :dispatch_attempts, :last_dispatch_error, :items_count, :created_at
    )
    expect(json).to include(id: order.id, order_type: "delivery", total_clp: order.total_clp)
  end

  it "cuenta todos los ítems de la orden" do
    order = create(:order, items_count: 3)

    expect(described_class.new(order).as_json[:items_count]).to eq(3)
  end
end