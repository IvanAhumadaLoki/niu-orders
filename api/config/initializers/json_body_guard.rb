require "json"
require "stringio"

# Middleware que rechaza con 400 los cuerpos JSON mal formados, antes de que
# lleguen a Rails.
#
# Por qué es un middleware: Rails analiza el cuerpo JSON de forma temprana y
# diferida, y el error resultante se maneja distinto según el entorno. Aquí se
# valida una sola vez, en un punto fijo, y la respuesta es idéntica siempre.
#
# Solo actúa sobre peticiones con Content-Type JSON. Un cuerpo vacío se deja
# pasar: lo resolverán las validaciones de la API (422).
class JsonBodyGuard
  JSON_MEDIA_TYPE = %r{\Aapplication/(?:[\w.+-]+\+)?json\z}

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if json_request?(request)
      body = request.body&.read.to_s
      # Leer el cuerpo lo consume; se deja disponible para el resto de la app.
      env["rack.input"] = StringIO.new(body)

      return invalid_json_response unless valid_json?(body)
    end

    @app.call(env)
  end

  private

  def json_request?(request)
    request.media_type.to_s.match?(JSON_MEDIA_TYPE)
  end

  def valid_json?(body)
    return true if body.strip.empty?

    JSON.parse(body)
    true
  rescue JSON::ParserError
    false
  end

  # Misma estructura que el resto de los errores (ver ErrorResponder).
  def invalid_json_response
    payload = {
      error: {
        code: "invalid_json",
        message: "El cuerpo de la petición no es un JSON válido"
      }
    }.to_json

    [
      400,
      { "content-type" => "application/json; charset=utf-8", "content-length" => payload.bytesize.to_s },
      [ payload ]
    ]
  end
end

Rails.application.config.middleware.use JsonBodyGuard