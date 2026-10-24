# Catálogo de productos que se pueden incluir en una orden.
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      # Precio en pesos chilenos (CLP). Entero porque el CLP no tiene decimales.
      t.integer :price_clp, null: false

      t.timestamps
    end

    add_index :products, :sku, unique: true

    # Red de seguridad a nivel de base de datos: nunca se guarda un precio <= 0.
    add_check_constraint :products, "price_clp > 0", name: "products_price_clp_positive"
  end
end