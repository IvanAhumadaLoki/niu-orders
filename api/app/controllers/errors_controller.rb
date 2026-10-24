# Responde a las rutas que no existen, con el mismo formato de error del resto
# de la API. Se activa desde la ruta comodín al final de config/routes.rb.
class ErrorsController < ApplicationController
  def not_found
    render_error(
      code: "not_found",
      message: "No existe la ruta #{request.request_method} #{request.path}",
      status: 404
    )
  end
end