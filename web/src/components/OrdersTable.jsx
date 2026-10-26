import { ORDER_TYPE_LABELS, formatClp, formatDateTime } from "../lib/format.js";
import StatusBadge from "./StatusBadge.jsx";

// Tabla con las órdenes de una página. Solo dibuja lo que recibe: no pide
// datos ni guarda estado, lo que la hace fácil de probar y de reutilizar.
//
// `orders` son los resúmenes que entrega GET /api/v1/orders.
export default function OrdersTable({ orders }) {
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
          {orders.map((order) => (
            <tr key={order.id}>
              <td className="order-number">{`#${order.id}`}</td>
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
          ))}
        </tbody>
      </table>
    </div>
  );
}