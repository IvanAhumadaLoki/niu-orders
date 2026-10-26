require "rails_helper"

# Verifica que la API encole el despacho de la orden apenas la guarda.
# Con Sidekiq en modo "fake" (spec/support/sidekiq.rb), los jobs quedan en
# DispatchOrderJob.jobs sin ejecutarse.
RSpec.describe "POST /api/v1/orders: despacho", type: :request do
  include_context "payload de orden"

  it "encola el despacho de la orden creada" do
    expect { post_order(payload) }.to change { DispatchOrderJob.jobs.size }.by(1)

    expect(response).to have_http_status(201)
    expect(DispatchOrderJob.jobs.last["args"]).to eq([ response.parsed_body["id"] ])
  end

  it "no encola nada si la orden es inválida" do
    expect { post_order(payload.except(:delivery_address)) }
      .not_to change { DispatchOrderJob.jobs.size }

    expect(response).to have_http_status(422)
  end
end