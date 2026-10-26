# CORS: qué sitios web pueden leer esta API desde un navegador.
#
# Un navegador bloquea que una página (por ejemplo el dashboard en
# http://localhost:5173) lea datos de otro origen (la API en
# http://localhost:3000) salvo que la API lo autorice con cabeceras CORS.
# Esta restricción es solo de los navegadores: los clientes de servidor, como
# los canales que crean órdenes o el simulador, no se ven afectados.
#
# Orígenes autorizados: variable CORS_ORIGINS, separados por coma. Ejemplo:
#   CORS_ORIGINS=https://panel.ejemplo.cl,https://admin.ejemplo.cl
# Si no está definida, en desarrollo y test se autoriza el dashboard local
# (Vite, puerto 5173). En producción NO hay valor por defecto: sin la variable
# el middleware no se activa, y ningún sitio externo puede leer la API desde
# un navegador.
default_origins = Rails.env.production? ? "" : "http://localhost:5173,http://127.0.0.1:5173"
allowed_origins = ENV.fetch("CORS_ORIGINS", default_origins).split(",").map(&:strip).reject(&:empty?)

unless allowed_origins.empty?
  # `insert_before 0` pone CORS primero en la cadena de middlewares, para que
  # hasta las respuestas de error (400 por JSON mal formado, 404, 500) lleven
  # las cabeceras; si no, el navegador mostraría un error de CORS en vez del
  # error real.
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed_origins)

      # Solo lectura desde el navegador: el dashboard consulta órdenes pero no
      # las crea (eso lo hacen los canales, desde servidores). Solo bajo /api/*:
      # ni el health check ni la tienda simulada quedan expuestos.
      # `max_age` deja que el navegador recuerde la autorización 10 minutos y
      # evite repetir la consulta previa (preflight) en cada petición.
      resource "/api/*",
               headers: :any,
               methods: %i[get head options],
               max_age: 600
    end
  end
end