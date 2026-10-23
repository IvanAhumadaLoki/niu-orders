# Permite usar `create(:order)` y `build(:order)` directamente en los specs,
# sin escribir el prefijo `FactoryBot.`.
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end