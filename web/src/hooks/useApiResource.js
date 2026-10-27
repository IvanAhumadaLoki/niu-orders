import { useCallback, useEffect, useRef, useState } from "react";

// Hook genérico: pide un recurso a la API, lo mantiene al día y expone su estado.
// Es la base de `useOrders` (listado) y `useOrder` (detalle).
//
//   const { data, loading, error, updatedAt, reload } = useApiResource(fetcher, { refreshInterval: 5000 });
//
// - fetcher:   función que devuelve una promesa con los datos. DEBE ser estable
//              entre renders (por ejemplo, envuelta en useCallback): cuando
//              cambia, se entiende que se pide otra cosa y se vuelve a cargar.
// - data:      datos de la última respuesta (null hasta la primera carga)
// - loading:   hay una carga VISIBLE en curso (primera carga, cambio de
//              `fetcher` o `reload`). Las actualizaciones automáticas no la activan.
// - error:     el error de la última petición, o null
// - updatedAt: Date de la última respuesta recibida, o null
// - reload:    vuelve a pedir el recurso
//
// `refreshInterval` (ms) activa la actualización automática; 0 la desactiva.
// Esas actualizaciones son SILENCIOSAS: no ponen `loading`, para que la pantalla
// no parpadee cada pocos segundos. Además:
//   - no se lanza una nueva mientras la anterior sigue en curso;
//   - se pausan con la pestaña oculta y se hace una al volver a verla.
//
// En todos los casos se CONSERVAN los datos anteriores mientras llegan los
// nuevos, y también si una petición falla: el error se muestra aparte y la
// pantalla no queda vacía. El siguiente éxito lo limpia.
export function useApiResource(fetcher, { refreshInterval = 0 } = {}) {
  const [state, setState] = useState({ data: null, loading: true, error: null, updatedAt: null });
  const [reloadCount, setReloadCount] = useState(0);
  // Número de la última petición lanzada: una respuesta solo se aplica si sigue
  // siendo la última. Así una respuesta vieja nunca pisa a una más nueva.
  const latestRequest = useRef(0);
  // Hay una petición en curso (la última lanzada).
  const pending = useRef(false);

  const load = useCallback(
    async ({ silent }) => {
      const requestId = ++latestRequest.current;
      pending.current = true;

      if (!silent) setState((previous) => ({ ...previous, loading: true, error: null }));

      try {
        const data = await fetcher();
        if (requestId !== latestRequest.current) return;

        setState({ data, loading: false, error: null, updatedAt: new Date() });
      } catch (error) {
        if (requestId !== latestRequest.current) return;

        setState((previous) => ({ ...previous, loading: false, error }));
      } finally {
        if (requestId === latestRequest.current) pending.current = false;
      }
    },
    [fetcher],
  );

  // Carga visible: al montar, al cambiar `fetcher` y en cada `reload`.
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