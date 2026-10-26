import { useCallback, useEffect, useState } from "react";
import { client } from "../api/client.js";

// Carga una página del listado de órdenes y expone su estado.
//
//   const { orders, meta, loading, error, reload } = useOrders({ page: 1, per_page: 10 });
//
// - orders:  órdenes de la página actual
// - meta:    { page, per_page, total_count, total_pages } (null hasta la primera carga)
// - loading: hay una petición en curso
// - error:   ApiError de la última petición, o null
// - reload:  vuelve a pedir la página actual
//
// Mientras llega una página nueva se CONSERVAN las órdenes anteriores, para que
// la tabla no parpadee. Si una carga falla, también se conservan: el error se
// muestra aparte y la pantalla no queda vacía.
//
// `params` puede ser un objeto nuevo en cada render: se compara por su contenido
// (serializado), así solo se vuelve a pedir cuando algún valor realmente cambia.
export function useOrders(params = {}) {
  const [state, setState] = useState({ orders: [], meta: null, loading: true, error: null });
  const [reloadCount, setReloadCount] = useState(0);
  const paramsKey = JSON.stringify(params);

  useEffect(() => {
    // Evita aplicar una respuesta vieja si, mientras tanto, cambiaron los
    // parámetros o se desmontó el componente.
    let cancelled = false;

    setState((previous) => ({ ...previous, loading: true, error: null }));

    client
      .listOrders(JSON.parse(paramsKey))
      .then((body) => {
        if (!cancelled) setState({ orders: body.data, meta: body.meta, loading: false, error: null });
      })
      .catch((error) => {
        if (!cancelled) setState((previous) => ({ ...previous, loading: false, error }));
      });

    return () => {
      cancelled = true;
    };
  }, [paramsKey, reloadCount]);

  const reload = useCallback(() => setReloadCount((count) => count + 1), []);

  return { ...state, reload };
}