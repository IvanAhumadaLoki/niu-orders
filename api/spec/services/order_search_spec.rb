require "rails_helper"

RSpec.describe OrderSearch do
  def search(params = {})
    described_class.call(params)
  end

  it "usa la primera página y 20 por página por defecto" do
    result = search

    expect(result).to be_success
    expect(result.meta).to eq(page: 1, per_page: 20, total_count: 0, total_pages: 0)
  end

  it "acepta los parámetros como texto, tal como llegan desde la URL" do
    create_list(:order, 3)

    result = search("page" => "2", "per_page" => "2")

    expect(result.meta).to eq(page: 2, per_page: 2, total_count: 3, total_pages: 2)
    expect(result.orders.to_a.size).to eq(1)
  end

  it "recorta per_page al máximo permitido" do
    expect(search(per_page: "500").meta[:per_page]).to eq(100)
  end

  it "informa cada parámetro inválido con su mensaje" do
    result = search(page: "0", per_page: "-1", dispatch_status: "foo", order_type: "drone", restaurant_id: "abc")

    expect(result).not_to be_success
    expect(result.errors.keys).to contain_exactly(:page, :per_page, :dispatch_status, :order_type, :restaurant_id)
    expect(result.errors[:dispatch_status].first).to include("pending", "sent", "error")
  end
end