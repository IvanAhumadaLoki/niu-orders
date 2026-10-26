# WebMock intercepta las peticiones HTTP salientes en los tests.
# Con `disable_net_connect!`, cualquier petición real falla: los specs deben
# declarar sus respuestas con `stub_request`, así los tests no dependen de
# ninguna tienda ni de la red.
require "webmock/rspec"

WebMock.disable_net_connect!