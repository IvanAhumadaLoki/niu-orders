# Productos incluidos en cada orden, con su cantidad.
# Guarda una copia del precio al momento de la compra (unit_price_clp), para que
# un cambio posterior en el catálogo no altere órdenes históricas.
class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      # Sin índice propio: lo cubre el índice único compuesto de más abajo.
      t.references :order, null: false, foreign_key: true, index: false
      t.references :product, null: false, foreign_key: true

      t.integer :quantity, null: false
      t.integer :unit_price_clp, null: false
      t.integer :subtotal_clp, null: false

      t.timestamps
    end

    # Un mismo producto no puede repetirse dentro de una orden.
    add_index :order_items, %i[order_id product_id], unique: true

    add_check_constraint :order_items, "quantity > 0", name: "order_items_quantity_positive"
    add_check_constraint :order_items, "unit_price_clp > 0", name: "order_items_unit_price_positive"
    add_check_constraint :order_items, "subtotal_clp > 0", name: "order_items_subtotal_positive"
  end
end