import { useCallback } from "react";
import { client } from "../api/client.js";
import { useApiResource } from "./useApiResource.js";

// Una página del listado de órdenes (GET /api/v1/orders), mantenida al día.
//
//   const { orders, meta, loading, error, updatedAt, reload } =
//     useOrders({ page: 1, per_page: 10 }, { refreshInterval: 5000 });
//
// - orders: órdenes de la página actual
// - meta:   { page, per_page, total_count, total_pages } (null hasta la primera carga)
// - el resto (loading, error, updatedAt, reload) y las opciones, como
//   `refreshInterval`, están descritos en useApiResource.
//
// `params` puede ser un objeto nuevo en cada render: se compara por su contenido
// (serializado), así solo se vuelve a pedir cuando algún valor realmente cambia.
export function useOrders(params = {}, options = {}) {
  const paramsKey = JSON.stringify(params);
  const fetcher = useCallback(() => client.listOrders(JSON.parse(paramsKey)), [paramsKey]);
  const { data, ...resource } = useApiResource(fetcher, options);

  return { orders: data?.data ?? [], meta: data?.meta ?? null, ...resource };
}