# Ayudantes para probar el flujo completo de despacho (API -> job -> tienda).
#
# Uso:  include DispatchFlowHelpers
module DispatchFlowHelpers
  # Fija la probabilidad de fallo de la tienda simulada solo durante el bloque
  # (0 = nunca falla, 1 = siempre falla) y deja el valor anterior al terminar.
  def with_store_failure_rate(rate)
    original = ENV["MOCK_STORE_FAILURE_RATE"]
    ENV["MOCK_STORE_FAILURE_RATE"] = rate.to_s
    yield
  ensure
    ENV["MOCK_STORE_FAILURE_RATE"] = original
  end

  # Ejecuta los jobs de despacho que la API dejó en la cola (Sidekiq en modo
  # "fake" los guarda sin ejecutarlos) y vacía la cola.
  def process_enqueued_jobs
    order_ids = DispatchOrderJob.jobs.map { |job| job["args"].first }
    Sidekiq::Job.clear_all
    order_ids.each { |order_id| run_with_retries(order_id) }
  end

  # Emula el motor de reintentos de Sidekiq, que en modo "fake" no corre:
  # si el job lanza un error reintentable, lo ejecuta de nuevo hasta agotar los
  # reintentos definidos (RETRY_DELAYS.size reintentos, más el intento original)
  # y entonces avisa que se agotaron, como haría Sidekiq. No espera entre
  # intentos: el calendario de esperas se prueba aparte, en el spec del job.
  def run_with_retries(order_id)
    attempts = 0
    begin
      attempts += 1
      DispatchOrderJob.new.perform(order_id)
    rescue DispatchOrderJob::RetryableDeliveryError => e
      retry if attempts <= DispatchOrderJob::RETRY_DELAYS.size

      DispatchOrderJob.retries_exhausted(order_id, e)
    end
  end
end