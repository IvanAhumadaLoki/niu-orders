# Configuración de Rails para RSpec.
# Se carga con `require "rails_helper"` al inicio de cada spec que use Rails.
require "spec_helper"

# Los tests siempre corren en el entorno `test`, con su propia base de datos.
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# Evita ejecutar la suite contra producción por error.
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# Carga los archivos de configuración auxiliares de spec/support/.
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |file| require file }

# Si hay migraciones pendientes, falla con un mensaje claro
# en lugar de errores confusos a mitad de la suite.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Cada test corre dentro de una transacción que se revierte al terminar,
  # así los tests no se contaminan entre sí.
  config.use_transactional_fixtures = true

  # Deduce el tipo de spec (model, request, etc.) según su carpeta.
  config.infer_spec_type_from_file_location!

  # Oculta las líneas internas de Rails en los mensajes de error.
  config.filter_rails_from_backtrace!
end