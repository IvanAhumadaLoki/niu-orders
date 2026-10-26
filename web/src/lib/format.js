// Formato de montos, fechas y etiquetas que se muestran en el dashboard.

// Textos en español para los valores que entrega la API.
export const ORDER_TYPE_LABELS = {
  pickup: "Retiro",
  delivery: "Delivery",
};

export const DISPATCH_STATUS_LABELS = {
  pending: "Pendiente",
  sent: "Enviado",
  error: "Error",
};

const clpFormatter = new Intl.NumberFormat("es-CL", {
  style: "currency",
  currency: "CLP",
  maximumFractionDigits: 0,
});

// Monto en pesos chilenos, con separador de miles: 22470 -> "$22.470".
// Devuelve "—" si el valor no es un número.
export function formatClp(amount) {
  return Number.isFinite(amount) ? clpFormatter.format(amount) : "—";
}

// Devuelve las piezas de una fecha (día, mes, hora...) como un objeto,
// en la zona horaria indicada o, si no se indica, en la del navegador.
// Se arma con las piezas de Intl en vez de usar un formato regional completo,
// porque ese varía entre navegadores y versiones; así el resultado siempre
// tiene la misma forma. `hourCycle: "h23"` evita que la medianoche aparezca
// como "24:00".
function dateParts(date, options, timeZone) {
  return Object.fromEntries(
    new Intl.DateTimeFormat("es-CL", { ...options, hourCycle: "h23", timeZone })
      .formatToParts(date)
      .map((part) => [part.type, part.value]),
  );
}

// Fecha y hora como "26-10-2026 10:05".
// Devuelve "—" si no hay fecha o no es válida.
export function formatDateTime(isoString, timeZone) {
  if (!isoString) return "—";

  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) return "—";

  const parts = dateParts(
    date,
    { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" },
    timeZone,
  );

  return `${parts.day}-${parts.month}-${parts.year} ${parts.hour}:${parts.minute}`;
}

// Hora como "10:05:09", a partir de un objeto Date.
// Devuelve "—" si no es una fecha válida.
export function formatTime(date, timeZone) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return "—";

  const parts = dateParts(date, { hour: "2-digit", minute: "2-digit", second: "2-digit" }, timeZone);

  return `${parts.hour}:${parts.minute}:${parts.second}`;
}