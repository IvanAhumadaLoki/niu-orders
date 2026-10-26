# Conexión de Sidekiq a Redis.
#
# La API (cliente) usa esta conexión para ENCOLAR trabajos; el proceso de
# Sidekiq (servidor) la usa para LEERLOS y ejecutarlos. Ambos leen la URL de la
# variable de entorno REDIS_URL, que docker-compose.yml define como
# redis://redis:6379/0 (`redis` es el nombre del servicio en la red de Docker).
redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end