# Aísla los tests de la configuración de la tienda simulada del entorno.
#
# MOCK_STORE_FAILURE_RATE (ver docker-compose.yml) controla qué tan seguido
# falla la tienda simulada. En desarrollo puede estar en 1 ("siempre falla")
# para probar reintentos; sin este hook, ese valor se filtraría a los tests y
# los haría fallar por algo ajeno al código.
#
# Cada test parte con la tienda funcionando (0) y, al terminar, el valor
# original se restaura.
RSpec.configure do |config|
  config.around do |example|
    original = ENV["MOCK_STORE_FAILURE_RATE"]
    ENV["MOCK_STORE_FAILURE_RATE"] = "0"
    example.run
  ensure
    ENV["MOCK_STORE_FAILURE_RATE"] = original
  end
end