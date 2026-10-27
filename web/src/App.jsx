import { useCallback, useState } from "react";
import OrderDetailPanel from "./components/OrderDetailPanel.jsx";
import OrderFilters from "./components/OrderFilters.jsx";
import OrdersTable from "./components/OrdersTable.jsx";
import Pagination from "./components/Pagination.jsx";
import RefreshControls from "./components/RefreshControls.jsx";
import { useOrders } from "./hooks/useOrders.js";
import { EMPTY_FILTERS, hasActiveFilters } from "./lib/filters.js";

// Órdenes por página. Con 10, la tabla se lee completa sin desplazarse mucho.
const PER_PAGE = 10;

// Cada cuánto se actualiza el listado (y el detalle abierto) solo.
const REFRESH_INTERVAL_MS = 5000;

// Vista principal del dashboard: órdenes recibidas, de la más reciente a la
// más antigua, con su estado de despacho a tienda. Se puede filtrar, se
// mantiene al día sin recargar la página y, al elegir una orden, se abre su detalle.
export default function App() {
  const [page, setPage] = useState(1);
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [autoRefresh, setAutoRefresh] = useState(true);
  // ID de la orden abierta en el panel de detalle, o null si no hay ninguna.
  const [selectedId, setSelectedId] = useState(null);

  const refreshInterval = autoRefresh ? REFRESH_INTERVAL_MS : 0;

  // Los filtros vacíos no viajan en la URL (lo resuelve el cliente de la API).
  const { orders, meta, loading, error, updatedAt, reload } = useOrders(
    { page, per_page: PER_PAGE, ...filters },
    { refreshInterval },
  );

  // Con otros filtros el resultado es distinto: se vuelve a la primera página,
  // porque la que se estaba viendo podría ya no existir.
  function changeFilters(nextFilters) {
    setFilters(nextFilters);
    setPage(1);
  }

  // Estable entre renders: el panel lo usa como dependencia de su manejo de Esc.
  const closeDetail = useCallback(() => setSelectedId(null), []);

  const filtersActive = hasActiveFilters(filters);

  return (
    <main className="page">
      <header className="page-header">
        <div>
          <h1>Niu Orders</h1>
          <p className="subtitle">Órdenes recibidas y su despacho a tienda</p>
        </div>
        <RefreshControls
          auto={autoRefresh}
          onAutoChange={setAutoRefresh}
          onRefresh={reload}
          loading={loading}
          updatedAt={updatedAt}
          intervalSeconds={REFRESH_INTERVAL_MS / 1000}
        />
      </header>

      <OrderFilters filters={filters} onChange={changeFilters} />

      {/* Un error no vacía la pantalla: si ya había datos, se siguen viendo. */}
      {error && (
        <div className="alert" role="alert">
          <span>{error.message}</span>
          <button type="button" onClick={reload}>
            Reintentar
          </button>
        </div>
      )}

      {meta === null && loading && <p className="muted">Cargando órdenes…</p>}

      {meta && (
        // Mientras llega otra página se atenúa la tabla en vez de borrarla.
        <section className={`card${loading ? " card-loading" : ""}`} aria-busy={loading}>
          {orders.length === 0 && filtersActive ? (
            <p className="empty">No hay órdenes que coincidan con los filtros.</p>
          ) : (
            <OrdersTable orders={orders} selectedId={selectedId} onSelect={setSelectedId} />
          )}
          <Pagination
            page={meta.page}
            totalPages={meta.total_pages}
            totalCount={meta.total_count}
            onChange={setPage}
            disabled={loading}
          />
        </section>
      )}

      {/* `key` hace que al elegir otra orden el panel empiece de cero, sin
          mostrar por un instante los datos de la anterior. */}
      {selectedId !== null && (
        <OrderDetailPanel
          key={selectedId}
          orderId={selectedId}
          onClose={closeDetail}
          refreshInterval={refreshInterval}
        />
      )}
    </main>
  );
}