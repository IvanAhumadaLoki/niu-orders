import { useCallback, useEffect, useRef, useState } from "react";
import { client } from "../api/client.js";

// Carga una página del listado de órdenes, la mantiene al día y expone su estado.
//
//   const { orders, meta, loading, error, updatedAt, reload } =
//     useOrders({ page: 1, per_page: 10 }, { refreshInterval: 5000 });
//
// - orders:    órdenes de la página actual
// - meta:      { page, per_page, total_count, total_pages } (null hasta la primera carga)
// - loading:   hay una carga VISIBLE en curso (primera carga, cambio de
//              parámetros o `reload`). Las actualizaciones automáticas no la activan.
// - error:     ApiError de la última petición, o null
// - updatedAt: Date de la última respuesta recibida, o null
// - reload:    vuelve a pedir la página actual
//
// `refreshInterval` (ms) activa la actualización automática; 0 la desactiva.
// Esas actualizaciones son SILENCIOSAS: no ponen `loading`, para que la tabla
// no parpadee cada pocos segundos. Además:
//   - no se lanza una nueva mientras la anterior sigue en curso;
//   - se pausan con la pestaña oculta y se hace una al volver a verla.
//
// En todos los casos se CONSERVAN las órdenes anteriores mientras llegan las
// nuevas, y también si una petición falla: el error se muestra aparte y la
// pantalla no queda vacía. El siguiente éxito lo limpia.
//
// `params` puede ser un objeto nuevo en cada render: se compara por su contenido
// (serializado), así solo se vuelve a pedir cuando algún valor realmente cambia.
export function useOrders(params = {}, { refreshInterval = 0 } = {}) {
  const [state, setState] = useState({ orders: [], meta: null, loading: true, error: null, updatedAt: null });
  const [reloadCount, setReloadCount] = useState(0);
  // Número de la última petición lanzada: una respuesta solo se aplica si sigue
  // siendo la última. Así una respuesta vieja nunca pisa a una más nueva.
  const latestRequest = useRef(0);
  // Hay una petición en curso (la última lanzada).
  const pending = useRef(false);
  const paramsKey = JSON.stringify(params);

  const load = useCallback(
    async ({ silent }) => {
      const requestId = ++latestRequest.current;
      pending.current = true;

      if (!silent) setState((previous) => ({ ...previous, loading: true, error: null }));

      try {
        const body = await client.listOrders(JSON.parse(paramsKey));
        if (requestId !== latestRequest.current) return;

        setState({ orders: body.data, meta: body.meta, loading: false, error: null, updatedAt: new Date() });
      } catch (error) {
        if (requestId !== latestRequest.current) return;

        setState((previous) => ({ ...previous, loading: false, error }));
      } finally {
        if (requestId === latestRequest.current) pending.current = false;
      }
    },
    [paramsKey],
  );

  // Carga visible: al montar, al cambiar los parámetros y en cada `reload`.
  useEffect(() => {
    load({ silent: false });

    return () => {
      // Invalida la petición en curso (si la hay): su respuesta ya no aplica.
      latestRequest.current += 1;
      pending.current = false;
    };
  }, [load, reloadCount]);

  // Actualización automática, silenciosa.
  useEffect(() => {
    if (!refreshInterval) return undefined;

    const refresh = () => {
      if (document.visibilityState === "hidden" || pending.current) return;
      load({ silent: true });
    };

    const timer = setInterval(refresh, refreshInterval);
    // Al volver a la pestaña se actualiza de inmediato, sin esperar al próximo ciclo.
    document.addEventListener("visibilitychange", refresh);

    return () => {
      clearInterval(timer);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, [load, refreshInterval]);

  const reload = useCallback(() => setReloadCount((count) => count + 1), []);

  return { ...state, reload };
}