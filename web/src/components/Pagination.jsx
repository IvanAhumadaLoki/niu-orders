// Controles de paginación: página actual, total de órdenes y botones
// Anterior / Siguiente. No conoce la API: avisa con `onChange(nuevaPágina)`
// y quien lo usa decide qué hacer.
//
// `totalPages` es 0 cuando no hay resultados (así lo informa la API).
// `disabled` bloquea ambos botones, por ejemplo mientras se carga una página.
export default function Pagination({ page, totalPages, totalCount, onChange, disabled = false }) {
  const hasResults = totalPages > 0;
  const countLabel = totalCount === 1 ? "1 orden" : `${totalCount.toLocaleString("es-CL")} órdenes`;

  return (
    <nav className="pagination" aria-label="Paginación de órdenes">
      <span className="muted">
        {hasResults ? `Página ${page} de ${totalPages} · ${countLabel}` : "Sin resultados"}
      </span>
      <div className="pagination-buttons">
        <button type="button" onClick={() => onChange(page - 1)} disabled={disabled || page <= 1}>
          Anterior
        </button>
        <button
          type="button"
          onClick={() => onChange(page + 1)}
          disabled={disabled || !hasResults || page >= totalPages}
        >
          Siguiente
        </button>
      </div>
    </nav>
  );
}