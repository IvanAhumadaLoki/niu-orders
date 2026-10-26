import { EMPTY_FILTERS, hasActiveFilters } from "../lib/filters.js";
import { DISPATCH_STATUS_LABELS, ORDER_TYPE_LABELS } from "../lib/format.js";
import { STORES } from "../lib/stores.js";

// Filtros del listado: estado de despacho, tienda y tipo de pedido.
//
// Es un componente controlado: recibe los filtros actuales y avisa con
// `onChange(nuevosFiltros)`; quien lo usa decide qué hacer (por ejemplo,
// volver a la primera página). No guarda estado propio.
export default function OrderFilters({ filters, onChange }) {
  // Devuelve el manejador de un selector: cambia solo ese filtro y conserva los demás.
  const update = (name) => (event) => onChange({ ...filters, [name]: event.target.value });

  return (
    <div className="filters" role="group" aria-label="Filtros de órdenes">
      <div className="field">
        <label htmlFor="filter-status">Estado de despacho</label>
        <select id="filter-status" value={filters.dispatch_status} onChange={update("dispatch_status")}>
          <option value="">Todos</option>
          {Object.entries(DISPATCH_STATUS_LABELS).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label htmlFor="filter-store">Tienda</label>
        <select id="filter-store" value={filters.restaurant_id} onChange={update("restaurant_id")}>
          <option value="">Todas</option>
          {STORES.map((store) => (
            <option key={store.id} value={String(store.id)}>
              {store.name}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label htmlFor="filter-type">Tipo de pedido</label>
        <select id="filter-type" value={filters.order_type} onChange={update("order_type")}>
          <option value="">Todos</option>
          {Object.entries(ORDER_TYPE_LABELS).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </div>

      <button type="button" onClick={() => onChange(EMPTY_FILTERS)} disabled={!hasActiveFilters(filters)}>
        Limpiar filtros
      </button>
    </div>
  );
}