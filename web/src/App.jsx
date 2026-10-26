import { useEffect, useState } from "react";
import { client } from "./api/client.js";

// Pantalla provisoria: comprueba que el dashboard puede hablar con la API.
// Pide una sola orden solo para leer el total registrado. Si el navegador
// bloquea la lectura por CORS, o la API está caída, se ve aquí.
// Se reemplaza por el listado de órdenes en el siguiente commit.
export default function App() {
  const [connection, setConnection] = useState({ state: "loading" });

  useEffect(() => {
    // Evita actualizar el estado si el componente se desmonta antes de responder.
    let cancelled = false;

    client
      .listOrders({ per_page: 1 })
      .then((body) => {
        if (!cancelled) setConnection({ state: "ok", total: body.meta.total_count });
      })
      .catch((error) => {
        if (!cancelled) setConnection({ state: "error", message: error.message });
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <main className="page">
      <header>
        <h1>Niu Orders</h1>
        <p className="subtitle">Dashboard de órdenes</p>
      </header>

      <section className="card" aria-live="polite">
        <h2>Conexión con la API</h2>
        {connection.state === "loading" && <p>Conectando…</p>}
        {connection.state === "ok" && (
          <p className="ok">
            Conectado. La API tiene {connection.total.toLocaleString("es-CL")} órdenes registradas.
          </p>
        )}
        {connection.state === "error" && <p className="error">{connection.message}</p>}
      </section>
    </main>
  );
}