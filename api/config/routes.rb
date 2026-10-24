# Rutas de la API.
# Todo el contenido de negocio vive bajo /api/v1; el prefijo de versión permite
# evolucionar la API sin romper a los clientes que ya la usan.
Rails.application.routes.draw do
  # Health check de Rails: responde 200 si la app arrancó sin errores.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Por ahora solo se puede crear órdenes; el listado y el detalle
      # se agregan junto con el dashboard.
      resources :orders, only: :create
    end
  end

  # Ruta comodín: DEBE ir al final. Captura cualquier ruta (o método) que no
  # coincida con las anteriores y responde 404 con el formato estándar.
  # Se excluye /rails/ para no interferir con las herramientas internas de Rails.
  match "*path", to: "errors#not_found", via: :all, format: false,
                 constraints: ->(request) { !request.path.start_with?("/rails/") }
end