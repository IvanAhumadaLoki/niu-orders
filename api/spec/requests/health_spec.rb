require "rails_helper"

# Prueba de humo: confirma que la suite está bien configurada y que la API
# arranca. Usa el health check que Rails expone en /up.
RSpec.describe "Health check", type: :request do
  it "responde 200 OK en /up" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end