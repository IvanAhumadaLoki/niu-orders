import { useCallback } from "react";
import { client } from "../api/client.js";
import { useApiResource } from "./useApiResource.js";

// Detalle de UNA orden (GET /api/v1/orders/:id), mantenido al día.
//
//   const { order, loading, error, updatedAt, reload } = useOrder(32, { refreshInterval: 5000 });
//
// Funciona como `useOrders` (ver useApiResource para el detalle de la carga y la
// actualización automática). Si `orderId` cambia, se entiende que es otra orden
// y se vuelve a cargar; quien lo use debería montar el componente con
// `key={orderId}` para no mostrar, mientras llega, los datos de la anterior.
export function useOrder(orderId, options = {}) {
  const fetcher = useCallback(() => client.getOrder(orderId), [orderId]);
  const { data, ...resource } = useApiResource(fetcher, options);

  return { order: data, ...resource };
}