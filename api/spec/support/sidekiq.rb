# Sidekiq en modo "fake" durante los tests: los jobs encolados quedan en un
# arreglo en memoria (DispatchOrderJob.jobs) y NO se ejecutan ni tocan Redis.
# Así los tests de la API pueden comprobar qué se encoló sin depender de Redis.
require "sidekiq/testing"

Sidekiq::Testing.fake!

RSpec.configure do |config|
  # Cada test parte con la cola vacía.
  config.before { Sidekiq::Job.clear_all }
end