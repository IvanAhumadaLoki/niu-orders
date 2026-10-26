import { DISPATCH_STATUS_LABELS } from "../lib/format.js";

// Etiqueta con el estado de despacho de una orden (Pendiente, Enviado o Error).
// El estado se comunica con TEXTO además del color, para que no dependa de
// distinguir colores. `detail` (por ejemplo el último error) aparece al pasar
// el mouse por encima.
export default function StatusBadge({ status, detail }) {
  const label = DISPATCH_STATUS_LABELS[status] ?? status;

  return (
    <span className={`badge badge-${status}`} title={detail || undefined}>
      {label}
    </span>
  );
}