import { useOrder } from "../hooks/useOrder.js";
import OrderDetail from "./OrderDetail.jsx";

// Panel de detalle con su carga de datos: pide la orden a la API, la mantiene
// al día mientras está abierto y se la entrega a OrderDetail para dibujarla.
//
// `refreshInterval` (ms) es cada cuánto se actualiza; 0 lo desactiva.
// Conviene montarlo con `key={orderId}`: al elegir otra orden empieza de cero,
// en vez de mostrar por un instante los datos de la anterior.
export default function OrderDetailPanel({ orderId, onClose, refreshInterval = 0 }) {
  const { order, loading, error, reload } = useOrder(orderId, { refreshInterval });

  return (
    <OrderDetail
      orderId={orderId}
      order={order}
      loading={loading}
      error={error}
      onClose={onClose}
      onRetry={reload}
    />
  );
}