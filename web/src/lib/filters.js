// Filtros del listado de órdenes. Un valor vacío ("") significa "sin filtrar":
// el cliente de la API omite los parámetros vacíos al armar la URL.
export const EMPTY_FILTERS = Object.freeze({
  dispatch_status: "",
  restaurant_id: "",
  order_type: "",
});

// true si hay al menos un filtro elegido.
export function hasActiveFilters(filters) {
  return Object.values(filters).some((value) => value !== "");
}