# Órdenes recibidas por la API central.
# Cada orden pertenece a un restaurante y lleva el estado de su despacho a tienda.
class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :restaurant, null: false, foreign_key: true

      # Tipo de pedido: "pickup" (retiro) o "delivery".
      t.string :order_type, null: false

      # Datos del cliente (viven en la orden: la prueba no gestiona clientes).
      t.string :customer_name, null: false
      t.string :customer_phone, null: false
      # Solo se exige cuando el pedido es delivery (se valida en el modelo).
      t.text :delivery_address

      # Total en CLP, calculado siempre por el servidor a partir de los ítems.
      t.integer :total_clp, null: false, default: 0

      # Estado del despacho a la tienda: "pending", "sent" o "error".
      t.string :dispatch_status, null: false, default: "pending"
      t.integer :dispatch_attempts, null: false, default: 0
      t.text :last_dispatch_error
      t.datetime :dispatched_at

      t.timestamps
    end

    # Índices pensados para el dashboard: filtrar por estado y ordenar por fecha.
    add_index :orders, :dispatch_status
    add_index :orders, :created_at

    # Red de seguridad a nivel de base de datos, además de las validaciones del modelo.
    add_check_constraint :orders, "order_type IN ('pickup', 'delivery')",
                         name: "orders_order_type_valid"
    add_check_constraint :orders, "dispatch_status IN ('pending', 'sent', 'error')",
                         name: "orders_dispatch_status_valid"
    add_check_constraint :orders, "total_clp >= 0", name: "orders_total_clp_non_negative"
    add_check_constraint :orders, "dispatch_attempts >= 0",
                         name: "orders_dispatch_attempts_non_negative"
  end
end