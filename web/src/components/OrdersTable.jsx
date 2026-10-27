import { ORDER_TYPE_LABELS, formatClp, formatDateTime } from "../lib/format.js";
import StatusBadge from "./StatusBadge.jsx";

// Tabla con las órdenes de una página. Solo dibuja lo que recibe: no pide
// datos ni guarda estado, lo que la hace fácil de probar y de reutilizar.
//
//   orders:     resúmenes que entrega GET /api/v1/orders
//   selectedId: ID de la orden abierta en el detalle (se resalta su fila)
//   onSelect:   se llama con el ID de la orden elegida
//
// Elegir una orden: clic en cualquier parte de la fila, o con teclado en el
// botón de su número (Tab para llegar, Enter para abrir). Ese botón no tiene su
// propio manejador: su clic sube hasta la fila, que es la que avisa, así
// `onSelect` se llama una sola vez por selección.
export default function OrdersTable({ orders, selectedId = null, onSelect = () => {} }) {
  if (orders.length === 0) {
    return <p className="empty">Aún no hay órdenes registradas.</p>;
  }

  return (
    <div className="table-wrap">
      <table className="orders-table">
        <thead>
          <tr>
            <th scope="col">N.º de orden</th>
            <th scope="col">Tienda</th>
            <th scope="col" className="amount">
              Monto total
            </th>
            <th scope="col">Tipo</th>
            <th scope="col">Fecha y hora</th>
            <th scope="col">Estado de despacho</th>
          </tr>
        </thead>
        <tbody>
          {orders.map((order) => {
            const selected = order.id === selectedId;

            return (
              <tr
                key={order.id}
                className={selected ? "row-selected" : undefined}
                aria-current={selected ? "true" : undefined}
                onClick={() => onSelect(order.id)}
              >
                <td className="order-number">
                  <button type="button" className="link-button" aria-label={`Ver detalle de la orden #${order.id}`}>
                    {`#${order.id}`}
                  </button>
                </td>
                <td>
                  {order.restaurant.name}
                  <span className="muted">{` · ${order.restaurant.code}`}</span>
                </td>
                <td className="amount">{formatClp(order.total_clp)}</td>
                <td>{ORDER_TYPE_LABELS[order.order_type] ?? order.order_type}</td>
                <td>{formatDateTime(order.created_at)}</td>
                <td>
                  <StatusBadge status={order.dispatch_status} detail={order.last_dispatch_error} />
                  {/* Solo se menciona cuando hubo reintentos: un único intento no aporta información. */}
                  {order.dispatch_attempts > 1 && (
                    <span className="muted">{` ${order.dispatch_attempts} intentos`}</span>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}