# Despacha en segundo plano una orden ya guardada a la tienda de su restaurante
# y deja registrado en la orden qué pasó.
#
# La API lo encola apenas guarda la orden (ver OrderCreator). Así, responder al
# canal que envió la orden no depende de que la tienda esté disponible.
#
# Qué hace en cada intento (usa StoreDispatcher):
#   1. Si la orden ya fue enviada, termina: no se duplica el pedido en la tienda.
#   2. Cuenta el intento en la orden.
#   3. Según el resultado:
#      entregada    -> la orden queda "sent" con su fecha de envío.
#      reintentable (5xx, timeout, error de red...) -> guarda el motivo, la orden
#                   sigue "pending" y lanza RetryableDeliveryError para que
#                   Sidekiq programe otro intento.
#      rechazada (4xx) -> la orden queda "error"; reintentar no lo arreglaría.
#
# Reintentos: hasta RETRY_DELAYS.size reintentos (6 intentos en total) con la
# espera creciente de RETRY_DELAYS. Si se agotan, la orden queda "error" (ver
# `retries_exhausted`) y Sidekiq mueve el job a su conjunto de "muertos".
#
# El job recibe el ID de la orden y no el objeto: los argumentos viajan como
# JSON por Redis, y leer la orden en cada intento garantiza datos actualizados.
class DispatchOrderJob
  include Sidekiq::Job

  # Segundos de espera antes de cada reintento (el primero espera 5 s, etc.).
  RETRY_DELAYS = [ 5, 15, 30, 60, 120 ].freeze

  # Falla transitoria de entrega. Se lanza a propósito: es la señal con la que
  # Sidekiq sabe que debe reintentar el job.
  class RetryableDeliveryError < StandardError; end

  # Un reintento por cada espera definida (más el intento original).
  sidekiq_options retry: RETRY_DELAYS.size

  # Reemplaza el calendario de espera por defecto de Sidekiq por RETRY_DELAYS.
  sidekiq_retry_in { |count, _exception| DispatchOrderJob.retry_delay(count) }

  # Sidekiq lo ejecuta cuando ya no quedan reintentos. Delega en un método de
  # clase para poder probarlo sin simular el motor de reintentos.
  sidekiq_retries_exhausted do |job, exception|
    DispatchOrderJob.retries_exhausted(job["args"].first, exception)
  end

  # Espera antes del reintento número `count` (0 para el primero). Si hubiera
  # más reintentos que esperas definidas, se repite la última.
  def self.retry_delay(count)
    RETRY_DELAYS.fetch(count, RETRY_DELAYS.last)
  end

  # Deja la orden en "error" cuando se agotaron los reintentos. No pisa una
  # orden que, por cualquier razón, ya figure como enviada.
  def self.retries_exhausted(order_id, exception)
    order = Order.find_by(id: order_id)
    return if order.nil? || order.dispatch_sent?

    order.mark_dispatch_error!("Se agotaron los reintentos. Último error: #{exception.message}")
  end

  def perform(order_id)
    order = Order.find_by(id: order_id)

    # La orden pudo borrarse entre el encolado y la ejecución: no hay nada
    # que despachar y reintentar no cambiaría eso.
    unless order
      logger.warn("[DispatchOrderJob] La orden ##{order_id} ya no existe; se descarta")
      return
    end

    # Idempotencia: si el mismo job se ejecuta dos veces, la segunda no reenvía.
    if order.dispatch_sent?
      logger.info("[DispatchOrderJob] La orden ##{order.id} ya fue entregada; no se reenvía")
      return
    end

    order.register_dispatch_attempt!
    result = StoreDispatcher.call(order)

    if result.delivered?
      order.mark_dispatched!
      logger.info("[DispatchOrderJob] Orden ##{order.id} entregada a la tienda " \
                  "#{order.restaurant.code} (HTTP #{result.http_status}) " \
                  "tras #{order.dispatch_attempts} intento(s)")
    elsif result.retryable?
      order.record_dispatch_failure!(result.message)
      raise RetryableDeliveryError, "Orden ##{order.id}: #{result.message}"
    else
      order.mark_dispatch_error!(result.message)
      logger.error("[DispatchOrderJob] Orden ##{order.id} rechazada por la tienda; " \
                   "no se reintenta. #{result.message}")
    end
  end
end