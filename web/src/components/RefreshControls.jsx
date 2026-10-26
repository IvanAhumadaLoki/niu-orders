import { formatTime } from "../lib/format.js";

// Controles de actualización del listado: casilla de actualización automática,
// hora de la última actualización y botón para actualizar a mano.
// No pide datos: avisa con `onAutoChange(boolean)` y `onRefresh()`.
export default function RefreshControls({ auto, onAutoChange, onRefresh, loading, updatedAt, intervalSeconds = 5 }) {
  return (
    <div className="refresh">
      <label className="checkbox">
        <input type="checkbox" checked={auto} onChange={(event) => onAutoChange(event.target.checked)} />
        {`Actualizar automáticamente cada ${intervalSeconds} s`}
      </label>
      <span className="muted">{updatedAt ? `Actualizado a las ${formatTime(updatedAt)}` : "Sin actualizar aún"}</span>
      <button type="button" onClick={onRefresh} disabled={loading}>
        Actualizar
      </button>
    </div>
  );
}