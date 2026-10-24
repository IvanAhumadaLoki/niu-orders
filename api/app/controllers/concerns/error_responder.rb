# Formato único de errores para toda la API.
#
# Todas las respuestas de error tienen la misma forma:
#   { "error": { "code": "...", "message": "...", "details": { ... } } }
#
# - `code`: identificador estable, pensado para que lo lea un programa.
# - `message`: explicación breve para una persona.
# - `details`: opcional; en errores de validación, los mensajes por campo.
#
# Se incluye en ApplicationController, así que todos los controladores
# disponen de estos métodos y del manejo de errores inesperados.
module ErrorResponder
  extend ActiveSupport::Concern

  included do
    # Red de seguridad: cualquier excepción no prevista dentro de una acción
    # termina como un 500 en JSON en vez de una página de error.
    rescue_from StandardError, with: :render_internal_error
  end

  private

  def render_error(code:, message:, status:, details: nil)
    body = { code: code, message: message }
    body[:details] = details if details

    render json: { error: body }, status: status
  end

  # `errors` es un Hash por campo, por ejemplo el resultado de `errors.to_hash`.
  def render_validation_error(errors)
    render_error(
      code: "validation_failed",
      message: "Los datos enviados no son válidos",
      status: 422,
      details: errors
    )
  end

  # El detalle del error se registra en el log, pero NO se devuelve al cliente,
  # para no exponer información interna (rutas, consultas, nombres de clases).
  def render_internal_error(exception)
    backtrace = exception.backtrace&.first(15)&.join("\n")
    Rails.logger.error("#{exception.class}: #{exception.message}\n#{backtrace}")

    render_error(code: "internal_error", message: "Error interno del servidor", status: 500)
  end
end