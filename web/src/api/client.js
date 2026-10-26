// Cliente de la API de órdenes.
//
// Es el ÚNICO lugar del dashboard que habla con la API: los componentes llaman
// a `client.listOrders()` y `client.getOrder()` en vez de usar `fetch`. Así el
// formato de las URL y el manejo de errores viven en un solo sitio y se pueden
// probar sin red (ver client.test.js).
//
// Dirección de la API: variable de entorno VITE_API_URL (por defecto
// http://localhost:3000). Es la dirección que usa el NAVEGADOR, por eso es
// localhost y no el nombre interno de Docker.

const DEFAULT_BASE_URL = (import.meta.env.VITE_API_URL ?? "http://localhost:3000").replace(/\/+$/, "");

// Error de una llamada a la API.
//   status:  código HTTP, o null si ni siquiera hubo respuesta
//   code:    código estable del error de la API ("validation_failed",
//            "not_found"...), o "network_error" si no se pudo conectar
//   details: errores por campo (solo en los 422)
export class ApiError extends Error {
  constructor(message, { status = null, code = null, details = null, cause } = {}) {
    super(message, { cause });
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

// Lee el cuerpo como JSON; devuelve null si no lo es (por ejemplo, una página
// de error en HTML).
async function readJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

// Crea un cliente. `baseUrl` y `fetchImpl` se pueden reemplazar para los tests.
export function createClient({ baseUrl = DEFAULT_BASE_URL, fetchImpl = (...args) => fetch(...args) } = {}) {
  // GET con parámetros de URL. Los valores vacíos (undefined, null, "") se
  // omiten: así un filtro sin elegir no viaja como `?dispatch_status=`.
  async function get(path, params = {}) {
    const url = new URL(`${baseUrl}${path}`);
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null && value !== "") {
        url.searchParams.set(key, value);
      }
    }

    let response;
    try {
      response = await fetchImpl(url, { headers: { Accept: "application/json" } });
    } catch (error) {
      throw new ApiError("No se pudo conectar con la API. ¿Está levantada?", {
        code: "network_error",
        cause: error,
      });
    }

    const body = await readJson(response);

    if (!response.ok) {
      // Formato de error de la API: { error: { code, message, details } }
      const apiError = body?.error ?? {};
      throw new ApiError(apiError.message ?? `La API respondió ${response.status}`, {
        status: response.status,
        code: apiError.code ?? null,
        details: apiError.details ?? null,
      });
    }

    return body;
  }

  return {
    // GET /api/v1/orders -> { data: [...], meta: { page, per_page, total_count, total_pages } }
    // Filtros: page, per_page, dispatch_status, restaurant_id, order_type.
    listOrders: (filters = {}) => get("/api/v1/orders", filters),

    // GET /api/v1/orders/:id -> orden completa (cliente, dirección y productos)
    getOrder: (id) => get(`/api/v1/orders/${encodeURIComponent(id)}`),
  };
}

// Cliente listo para usar en la aplicación.
export const client = createClient();