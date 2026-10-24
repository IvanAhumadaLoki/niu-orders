# Controlador base de la API.
# Incluye el manejo de errores estándar (ver ErrorResponder).
class ApplicationController < ActionController::API
  include ErrorResponder
end