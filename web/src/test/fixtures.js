// Datos de ejemplo para los tests de componentes.

// Orden completa, con la misma forma que entrega GET /api/v1/orders/:id.
export const detailedOrder = {
  id: 32,
  restaurant: { id: 2, code: "LCON", name: "Niu Foods Las Condes" },
  order_type: "delivery",
  customer: { name: "Ana Pérez", phone: "+56912345678" },
  delivery_address: "Av. Providencia 1234, Santiago",
  total_clp: 22470,
  dispatch_status: "sent",
  dispatch_attempts: 2,
  dispatched_at: "2026-10-26T13:07:00Z",
  last_dispatch_error: null,
  created_at: "2026-10-26T13:05:00Z",
  items: [
    { product_id: 1, name: "Niu Roll Salmón", sku: "SKU-001", quantity: 2, unit_price_clp: 8990, subtotal_clp: 17980 },
    { product_id: 5, name: "Gyozas de Pollo x5", sku: "SKU-005", quantity: 1, unit_price_clp: 4490, subtotal_clp: 4490 },
  ],
};