require "rails_helper"

# Verifica que los errores que no son de validación también usen el formato
# estándar: { "error": { "code": "...", "message": "..." } }
RSpec.describe "Respuestas de error estándar", type: :request do
  def error_body
    response.parsed_body["error"]
  end

  describe "ruta inexistente" do
    it "responde 404 con el formato estándar" do
      get "/api/v1/nada"

      expect(response).to have_http_status(404)
      expect(error_body).to include("code" => "not_found")
      expect(error_body["message"]).to include("GET /api/v1/nada")
    end

    it "responde 404 si el método no existe en una ruta conocida" do
      get "/api/v1/orders"

      expect(response).to have_http_status(404)
      expect(error_body).to include("code" => "not_found")
    end
  end

  describe "JSON mal formado" do
    let(:headers) { { "CONTENT_TYPE" => "application/json" } }

    it "responde 400 con el formato estándar" do
      post "/api/v1/orders", params: '{"restaurant_id": 2,', headers: headers

      expect(response).to have_http_status(400)
      expect(error_body).to include("code" => "invalid_json")
    end

    it "no crea ninguna orden" do
      expect { post "/api/v1/orders", params: "{roto", headers: headers }
        .not_to change(Order, :count)
    end

    it "deja pasar un cuerpo vacío, que termina en un error de validación" do
      post "/api/v1/orders", params: "", headers: headers

      expect(response).to have_http_status(422)
      expect(error_body).to include("code" => "validation_failed")
    end
  end

  describe "error inesperado" do
    it "responde 500 sin filtrar detalles internos" do
      allow(OrderCreator).to receive(:call).and_raise(StandardError, "secreto interno")

      post "/api/v1/orders", params: {}, as: :json

      expect(response).to have_http_status(500)
      expect(error_body).to include("code" => "internal_error")
      expect(response.body).not_to include("secreto interno")
    end
  end
end