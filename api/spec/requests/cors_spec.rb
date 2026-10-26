require "rails_helper"

# Verifica qué puede leer un navegador desde otro origen (CORS).
# El middleware se configura al arrancar la aplicación (config/initializers/cors.rb),
# con CORS_ORIGINS o, si no existe, el dashboard local en el puerto 5173.
RSpec.describe "CORS", type: :request do
  let(:allowed_origin) { ENV.fetch("CORS_ORIGINS", "http://localhost:5173").split(",").first.strip }
  let(:other_origin) { "http://sitio-ajeno.test" }

  it "autoriza al dashboard a leer el listado de órdenes" do
    get "/api/v1/orders", headers: { "Origin" => allowed_origin }

    expect(response).to have_http_status(200)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
  end

  it "no autoriza a otros orígenes" do
    get "/api/v1/orders", headers: { "Origin" => other_origin }

    # El servidor responde igual: quien bloquea la lectura es el navegador,
    # al no ver la cabecera que autoriza ese origen.
    expect(response).to have_http_status(200)
    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end

  it "responde la consulta previa (preflight) del navegador, solo para lectura" do
    options "/api/v1/orders",
            headers: { "Origin" => allowed_origin, "Access-Control-Request-Method" => "GET" }

    allowed_methods = response.headers["Access-Control-Allow-Methods"].to_s.downcase

    expect(response).to have_http_status(200)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
    expect(allowed_methods).to include("get")
    # Crear órdenes no está autorizado desde un navegador.
    expect(allowed_methods).not_to include("post")
  end

  it "no expone rutas fuera de /api, como el health check" do
    get "/up", headers: { "Origin" => allowed_origin }

    expect(response).to have_http_status(200)
    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end
end