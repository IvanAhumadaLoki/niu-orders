// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { client } from "../api/client.js";
import { detailedOrder } from "../test/fixtures.js";
import OrderDetailPanel from "./OrderDetailPanel.jsx";

// Se reemplaza el cliente de la API: estos tests miran el recorrido
// (cargando -> datos, o error -> reintento), no la red.
vi.mock("../api/client.js", () => ({ client: { getOrder: vi.fn() } }));

beforeEach(() => client.getOrder.mockReset());
afterEach(cleanup);

describe("OrderDetailPanel", () => {
  it("carga la orden por su ID y la muestra", async () => {
    client.getOrder.mockResolvedValue(detailedOrder);

    render(<OrderDetailPanel orderId={32} onClose={() => {}} />);
    expect(screen.getByText("Cargando detalle…")).toBeTruthy();

    expect(await screen.findByText("Ana Pérez")).toBeTruthy();
    expect(client.getOrder).toHaveBeenCalledWith(32);
    expect(screen.queryByText("Cargando detalle…")).toBeNull();
  });

  it("muestra el error y se recupera al reintentar", async () => {
    client.getOrder.mockRejectedValueOnce(new Error("La API respondió 500")).mockResolvedValueOnce(detailedOrder);

    render(<OrderDetailPanel orderId={32} onClose={() => {}} />);
    expect(await screen.findByText("La API respondió 500")).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Reintentar" }));

    expect(await screen.findByText("Ana Pérez")).toBeTruthy();
    expect(screen.queryByText("La API respondió 500")).toBeNull();
  });
});