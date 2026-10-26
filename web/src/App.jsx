import { useState } from "react";
import OrdersTable from "./components/OrdersTable.jsx";
import Pagination from "./components/Pagination.jsx";
import { useOrders } from "./hooks/useOrders.js";

// Órdenes por página. Con 10, la tabla se lee completa sin desplazarse mucho.
const PER_PAGE = 10;

// Vista principal del dashboard: órdenes recibidas, de la más reciente a la
// más antigua, con su estado de despacho a tienda.
export default function App() {
  const [page, setPage] = useState(1);
  const { orders, meta, loading, error, reload } = useOrders({ page, per_page: PER_PAGE });

  return (
    <main className="page">
      <header className="page-header">
        <div>
          <h1>Niu Orders</h1>
          <p className="subtitle">Órdenes recibidas y su despacho a tienda</p>
        </div>
        <button type="button" onClick={reload} disabled={loading}>
          Actualizar
        </button>
      </header>

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
          <OrdersTable orders={orders} />
          <Pagination
            page={meta.page}
            totalPages={meta.total_pages}
            totalCount={meta.total_count}
            onChange={setPage}
            disabled={loading}
          />
        </section>
      )}
    </main>
  );
}