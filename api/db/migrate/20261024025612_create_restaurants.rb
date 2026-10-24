# Tabla de restaurantes (tiendas) de la franquicia.
# Cada orden se despacha a un restaurante, identificado por su `code`.
class CreateRestaurants < ActiveRecord::Migration[8.1]
  def change
    create_table :restaurants do |t|
      t.string :name, null: false
      # Código corto y único de la tienda (PROV, LCON, NUNO).
      t.string :code, null: false

      t.timestamps
    end

    # La unicidad se garantiza también en la base de datos, no solo en el modelo:
    # protege frente a dos requests simultáneos que pasen la validación a la vez.
    add_index :restaurants, :code, unique: true
  end
end