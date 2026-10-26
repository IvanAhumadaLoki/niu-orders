// @vitest-environment jsdom
import { afterEach, describe, expect, it } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import OrdersTable from "./OrdersTable.jsx";

afterEach(cleanup);

// Resúmenes de orden con la misma forma que entrega GET /api/v1/orders.
const sentOrder = {
  id: 31,
  restaurant: { id: 2, code: "LCON", name: "Niu Foods Las Condes" },
  order_type: "pickup",
  total_clp: 22470,
  dispatch_status: "sent",
  dispatch_attempts: 1,
  last_dispatch_error: null,
  items_count: 2,
  created_at: "2026-10-26T13:05:00Z",
};

const failedOrder = {
  ...sentOrder,
  id: 32,
  order_type: "delivery",
  total_clp: 8990,
  dispatch_status: "error",
  dispatch_attempts: 6,
  last_dispatch_error: "Se agotaron los reintentos",
};

describe("OrdersTable", () => {
  it("muestra una fila por orden con sus datos principales", () => {
    render(<OrdersTable orders={[sentOrder, failedOrder]} />);

    // Encabezado + 2 órdenes.
    expect(screen.getAllByRole("row")).toHaveLength(3);
    expect(screen.getByText("#31")).toBeTruthy();
    expect(screen.getByText("#32")).toBeTruthy();
    expect(screen.getAllByText("Niu Foods Las Condes")).toHaveLength(2);
    expect(screen.getByText(/22\.470/)).toBeTruthy();
    expect(screen.getByText("Retiro")).toBeTruthy();
    expect(screen.getByText("Delivery")).toBeTruthy();
    expect(screen.getByText("Enviado")).toBeTruthy();
    // Las dos órdenes de ejemplo tienen la misma fecha, así que aparece dos veces.
    // Solo se comprueba la forma (día-mes-año hora:minuto), no la hora exacta,
    // porque depende de la zona horaria de quien ejecuta los tests.
    expect(screen.getAllByText(/^\d{2}-\d{2}-\d{4} \d{2}:\d{2}$/)).toHaveLength(2);
  });

  it("muestra el motivo del error y los intentos cuando el despacho falló", () => {
    render(<OrdersTable orders={[failedOrder]} />);

    expect(screen.getByText("Error").getAttribute("title")).toBe("Se agotaron los reintentos");
    expect(screen.getByText(/6 intentos/)).toBeTruthy();
  });

  it("no menciona los intentos cuando hubo uno solo", () => {
    render(<OrdersTable orders={[sentOrder]} />);

    expect(screen.queryByText(/intentos/)).toBeNull();
  });

  it("muestra un mensaje en vez de una tabla vacía cuando no hay órdenes", () => {
    render(<OrdersTable orders={[]} />);

    expect(screen.getByText("Aún no hay órdenes registradas.")).toBeTruthy();
    expect(screen.queryByRole("table")).toBeNull();
  });
});