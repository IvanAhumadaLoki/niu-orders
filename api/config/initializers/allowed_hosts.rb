# Dentro de Docker Compose, el despachador de órdenes (y más adelante Sidekiq)
# llama a la API por el nombre del servicio, `api`, así que hay que autorizarlo.
# Sin esto, la tienda simulada respondería 403 "Blocked host".
Rails.application.config.hosts << "api" if Rails.env.development?