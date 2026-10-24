# Datos iniciales de la prueba: restaurantes y catálogo de productos.
#
# Ejecutar con:  bin/rails db:seed
#
# - Es idempotente: se puede ejecutar varias veces sin duplicar registros,
#   porque cada fila se busca por su ID y se actualiza si ya existe.
# - Los IDs son explícitos a propósito: el payload de referencia de la prueba
#   (restaurant_id: 2, product_id: 1 y 5) depende de que coincidan con el dataset.
# - Precios en pesos chilenos (CLP), como enteros.

restaurants = [
  { id: 1, name: "Niu Foods Providencia", code: "PROV" },
  { id: 2, name: "Niu Foods Las Condes",  code: "LCON" },
  { id: 3, name: "Niu Foods Ñuñoa",       code: "NUNO" }
]

products = [
  { id: 1,  name: "Niu Roll Salmón",       sku: "SKU-001", price_clp: 8_990 },
  { id: 2,  name: "California Ebi",        sku: "SKU-002", price_clp: 7_490 },
  { id: 3,  name: "Avocado Roll",          sku: "SKU-003", price_clp: 6_990 },
  { id: 4,  name: "Nigiri Salmón x2",      sku: "SKU-004", price_clp: 3_990 },
  { id: 5,  name: "Gyozas de Pollo x5",    sku: "SKU-005", price_clp: 4_490 },
  { id: 6,  name: "Edamame",               sku: "SKU-006", price_clp: 3_290 },
  { id: 7,  name: "Bowl Salmón Teriyaki",  sku: "SKU-007", price_clp: 9_990 },
  { id: 8,  name: "Bowl Pollo Teriyaki",   sku: "SKU-008", price_clp: 8_990 },
  { id: 9,  name: "Bebida 350 ml",         sku: "SKU-009", price_clp: 1_990 },
  { id: 10, name: "Agua Mineral 500 ml",   sku: "SKU-010", price_clp: 1_590 }
]

# Todo o nada: si una fila falla, no queda un catálogo a medias.
ActiveRecord::Base.transaction do
  restaurants.each do |attrs|
    Restaurant.find_or_initialize_by(id: attrs[:id]).update!(attrs.except(:id))
  end

  products.each do |attrs|
    Product.find_or_initialize_by(id: attrs[:id]).update!(attrs.except(:id))
  end
end

# Al insertar IDs a mano, la secuencia de PostgreSQL no avanza sola.
# Se reinicia para que el próximo registro creado reciba el ID siguiente
# en vez de chocar con uno existente.
[Restaurant, Product].each do |model|
  ActiveRecord::Base.connection.reset_pk_sequence!(model.table_name)
end

puts "Seeds listos: #{Restaurant.count} restaurantes y #{Product.count} productos."