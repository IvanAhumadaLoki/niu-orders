import { useEffect, useRef } from "react";
import { ORDER_TYPE_LABELS, formatClp, formatDateTime } from "../lib/format.js";
import StatusBadge from "./StatusBadge.jsx";

// Panel lateral con el detalle de una orden. Solo dibuja lo que recibe: no pide
// datos (eso lo hace OrderDetailPanel), lo que lo hace fácil de probar.
//
//   orderId:  número de la orden (se muestra en el título mientras carga)
//   order:    orden completa (GET /api/v1/orders/:id), o null si aún no llega
//   loading:  hay una carga en curso
//   error:    error de la última petición, o null
//   onClose:  se llama al cerrar el panel (botón, tecla Esc o clic fuera)
//   onRetry:  se llama al pulsar «Reintentar»
//
// Accesibilidad: es un diálogo. Al abrirse enfoca el botón de cierre y, al
// cerrarse, devuelve el foco a lo que lo tenía antes (la fila elegida).
export default function OrderDetail({ orderId, order, loading, error, onClose, onRetry }) {
  const closeButton = useRef(null);

  // Foco al abrir y al cerrar. Va aparte del manejo de Esc para que no se
  // repita (y le robe el foco al usuario) cada vez que cambian los datos.
  useEffect(() => {
    const previouslyFocused = document.activeElement;
    closeButton.current?.focus();

    return () => previouslyFocused?.focus?.();
  }, []);

  useEffect(() => {
    const closeOnEscape = (event) => {
      if (event.key === "Escape") onClose();
    };

    document.addEventListener("keydown", closeOnEscape);
    return () => document.removeEventListener("keydown", closeOnEscape);
  }, [onClose]);

  return (
    // Un clic en el fondo oscuro cierra el panel; el panel frena el clic para
    // que lo que ocurra dentro no lo cierre.
    <div className="overlay" onClick={onClose}>
      <section
        className="detail"
        role="dialog"
        aria-modal="true"
        aria-labelledby="detail-title"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="detail-header">
          <h2 id="detail-title">{`Orden #${orderId}`}</h2>
          {order && <StatusBadge status={order.dispatch_status} detail={order.last_dispatch_error} />}
          <button type="button" className="detail-close" ref={closeButton} onClick={onClose} aria-label="Cerrar detalle">
            ×
          </button>
        </header>

        <div className="detail-body">
          {/* Un error no borra lo que ya se había cargado. */}
          {error && (
            <div className="alert" role="alert">
              <span>{error.message}</span>
              <button type="button" onClick={onRetry}>
                Reintentar
              </button>
            </div>
          )}

          {!order && loading && <p className="muted">Cargando detalle…</p>}

          {order && <OrderDetailContent order={order} />}
        </div>
      </section>
    </div>
  );
}

// Secciones del detalle: resumen, cliente, productos y despacho.
function OrderDetailContent({ order }) {
  const isDelivery = order.order_type === "delivery";

  return (
    <>
      <section className="detail-section">
        <h3>Resumen</h3>
        <dl className="fields">
          <dt>Tienda</dt>
          <dd>
            {order.restaurant.name}
            <span className="muted">{` · ${order.restaurant.code}`}</span>
          </dd>
          <dt>Tipo de pedido</dt>
          <dd>{ORDER_TYPE_LABELS[order.order_type] ?? order.order_type}</dd>
          <dt>Fecha y hora</dt>
          <dd>{formatDateTime(order.created_at)}</dd>
          <dt>Monto total</dt>
          <dd>{formatClp(order.total_clp)}</dd>
        </dl>
      </section>

      <section className="detail-section">
        <h3>Cliente</h3>
        <dl className="fields">
          <dt>Nombre</dt>
          <dd>{order.customer.name}</dd>
          <dt>Teléfono</dt>
          <dd>{order.customer.phone}</dd>
          <dt>{isDelivery ? "Dirección de entrega" : "Entrega"}</dt>
          <dd>{isDelivery ? order.delivery_address || "—" : "Retiro en tienda"}</dd>
        </dl>
      </section>

      <section className="detail-section">
        <h3>Productos</h3>
        <div className="table-wrap">
          <table className="items-table">
            <thead>
              <tr>
                <th scope="col">Producto</th>
                <th scope="col" className="amount">
                  Cant.
                </th>
                <th scope="col" className="amount">
                  Precio unitario
                </th>
                <th scope="col" className="amount">
                  Subtotal
                </th>
              </tr>
            </thead>
            <tbody>
              {order.items.map((item) => (
                <tr key={item.product_id}>
                  <td>
                    {item.name}
                    <span className="muted">{` · ${item.sku}`}</span>
                  </td>
                  <td className="amount">{item.quantity}</td>
                  <td className="amount">{formatClp(item.unit_price_clp)}</td>
                  <td className="amount">{formatClp(item.subtotal_clp)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr>
                <th scope="row" colSpan={3}>
                  Total
                </th>
                <td className="amount">{formatClp(order.total_clp)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>

      <section className="detail-section">
        <h3>Despacho a la tienda</h3>
        <dl className="fields">
          <dt>Intentos</dt>
          <dd>{order.dispatch_attempts}</dd>
          <dt>Fecha de envío</dt>
          <dd>{formatDateTime(order.dispatched_at)}</dd>
          {order.last_dispatch_error && (
            <>
              <dt>Último error</dt>
              <dd className="error-text">{order.last_dispatch_error}</dd>
            </>
          )}
        </dl>
      </section>
    </>
  );
}