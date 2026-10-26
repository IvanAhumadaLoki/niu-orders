require "rails_helper"

RSpec.describe "GET /api/v1/orders", type: :request do
  let(:providencia) { create(:restaurant, code: "PROV") }
  let(:las_condes) { create(:restaurant, code: "LCON") }

  def get_orders(params = {})
    get "/api/v1/orders", params: params
  end

  # IDs de las órdenes de la respuesta, en el orden en que llegaron.
  def ids
    response.parsed_body["data"].map { |order| order["id"] }
  end

  def meta
    response.parsed_body["meta"]
  end

  # Cuenta las consultas SQL que se ejecutan dentro del bloque.
  def count_queries
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])
    end

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  describe "orden y contenido" do
    it "ordena de la más reciente a la más antigua" do
      oldest = create(:order, created_at: 3.hours.ago)
      newest = create(:order, created_at: 1.hour.ago)
      middle = create(:order, created_at: 2.hours.ago)

      get_orders

      expect(response).to have_http_status(200)
      expect(ids).to eq([ newest.id, middle.id, oldest.id ])
    end

    it "incluye los datos que necesita el listado" do
      order = create(:order, :delivery, restaurant: las_condes)
      order.mark_dispatch_error!("La tienda rechazó la orden con 422")

      get_orders

      row = response.parsed_body["data"].first
      expect(row).to include(
        "id" => order.id,
        "restaurant" => { "id" => las_condes.id, "code" => "LCON", "name" => las_condes.name },
        "order_type" => "delivery",
        "total_clp" => order.total_clp,
        "dispatch_status" => "error",
        "dispatch_attempts" => 0,
        "last_dispatch_error" => "La tienda rechazó la orden con 422",
        "items_count" => 1
      )
      expect(Time.zone.parse(row["created_at"])).to be_within(5.seconds).of(order.created_at)
    end

    it "devuelve una lista vacía cuando no hay órdenes" do
      get_orders

      expect(response).to have_http_status(200)
      expect(response.parsed_body).to eq(
        "data" => [],
        "meta" => { "page" => 1, "per_page" => 20, "total_count" => 0, "total_pages" => 0 }
      )
    end
  end

  describe "paginación" do
    it "pagina los resultados e informa el total" do
      # orders[0] es la más reciente.
      orders = Array.new(5) { |i| create(:order, created_at: (i + 1).hours.ago) }

      get_orders(page: 2, per_page: 2)
      expect(ids).to eq(orders[2..3].map(&:id))
      expect(meta).to eq("page" => 2, "per_page" => 2, "total_count" => 5, "total_pages" => 3)

      get_orders(page: 3, per_page: 2)
      expect(ids).to eq([ orders[4].id ])

      get_orders(page: 4, per_page: 2)
      expect(ids).to eq([])
      expect(meta["total_count"]).to eq(5)
    end

    it "usa 20 órdenes por página por defecto" do
      create(:order)

      get_orders

      expect(meta).to include("page" => 1, "per_page" => 20)
    end

    it "limita per_page a 100 e informa el valor usado" do
      get_orders(per_page: 500)

      expect(response).to have_http_status(200)
      expect(meta["per_page"]).to eq(100)
    end
  end

  describe "filtros" do
    it "filtra por estado de despacho" do
      create(:order)
      sent = create(:order).tap(&:mark_dispatched!)
      create(:order).tap { |order| order.mark_dispatch_error!("falló") }

      get_orders(dispatch_status: "sent")

      expect(ids).to eq([ sent.id ])
      expect(meta["total_count"]).to eq(1)
    end

    it "filtra por restaurante" do
      prov_orders = create_list(:order, 2, restaurant: providencia)
      create(:order, restaurant: las_condes)

      get_orders(restaurant_id: providencia.id)

      expect(ids).to match_array(prov_orders.map(&:id))
    end

    it "filtra por tipo de pedido" do
      create(:order)
      delivery = create(:order, :delivery)

      get_orders(order_type: "delivery")

      expect(ids).to eq([ delivery.id ])
    end

    it "combina varios filtros" do
      target = create(:order, :delivery, restaurant: providencia).tap(&:mark_dispatched!)
      create(:order, :delivery, restaurant: providencia)                    # pendiente
      create(:order, :delivery, restaurant: las_condes).tap(&:mark_dispatched!) # otra tienda
      create(:order, restaurant: providencia).tap(&:mark_dispatched!)      # es pickup

      get_orders(restaurant_id: providencia.id, order_type: "delivery", dispatch_status: "sent")

      expect(ids).to eq([ target.id ])
    end
  end

  describe "parámetros inválidos" do
    it "responde 422 e indica cada parámetro con error" do
      get_orders(page: 0, per_page: "abc", dispatch_status: "foo", order_type: "drone", restaurant_id: "x")

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details").keys).to contain_exactly(
        "page", "per_page", "dispatch_status", "order_type", "restaurant_id"
      )
    end
  end

  describe "rendimiento" do
    it "no hace consultas extra por cada orden" do
      create_list(:order, 2)
      get_orders # calentamiento: la primera petición puede cargar metadatos

      few = count_queries { get_orders }
      create_list(:order, 4)
      many = count_queries { get_orders }

      expect(many).to eq(few)
    end
  end
end