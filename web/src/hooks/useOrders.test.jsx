// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { act, cleanup, renderHook } from "@testing-library/react";
import { client } from "../api/client.js";
import { useOrders } from "./useOrders.js";

// Se reemplaza el cliente de la API: estos tests miran CUÁNDO y con qué
// parámetros se piden las órdenes, no la red.
vi.mock("../api/client.js", () => ({ client: { listOrders: vi.fn() } }));

const INTERVAL = 5000;

// Respuesta del listado con órdenes que solo tienen `id`.
function pageOf(ids) {
  return {
    data: ids.map((id) => ({ id })),
    meta: { page: 1, per_page: 10, total_count: ids.length, total_pages: 1 },
  };
}

const idsOf = (result) => result.current.orders.map((order) => order.id);

// Deja pasar el tiempo (con temporizadores falsos) y resuelve lo que quede pendiente.
async function advance(ms) {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(ms);
  });
}

beforeEach(() => {
  vi.useFakeTimers();
  client.listOrders.mockReset();
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe("useOrders", () => {
  it("pide las órdenes al montarse, con los parámetros indicados", async () => {
    client.listOrders.mockResolvedValue(pageOf([1, 2]));

    const { result } = renderHook(() => useOrders({ page: 1, per_page: 10 }));
    expect(result.current.loading).toBe(true);

    await advance(0);

    expect(client.listOrders).toHaveBeenCalledTimes(1);
    expect(client.listOrders).toHaveBeenCalledWith({ page: 1, per_page: 10 });
    expect(result.current.loading).toBe(false);
    expect(idsOf(result)).toEqual([1, 2]);
    expect(result.current.meta.total_count).toBe(2);
    expect(result.current.updatedAt).toBeInstanceOf(Date);
  });

  it("se actualiza sola, sin mostrar la carga y sin apilar peticiones", async () => {
    let resolveSecond;
    client.listOrders
      .mockResolvedValueOnce(pageOf([1]))
      .mockReturnValueOnce(new Promise((resolve) => (resolveSecond = resolve)));

    const { result } = renderHook(() => useOrders({}, { refreshInterval: INTERVAL }));
    await advance(0);
    expect(idsOf(result)).toEqual([1]);

    await advance(INTERVAL);
    expect(client.listOrders).toHaveBeenCalledTimes(2);
    // La petición sigue en curso, pero es silenciosa: no hay indicador de carga.
    expect(result.current.loading).toBe(false);

    // Con la anterior todavía en curso, el siguiente ciclo no lanza otra encima.
    await advance(INTERVAL);
    expect(client.listOrders).toHaveBeenCalledTimes(2);

    await act(async () => {
      resolveSecond(pageOf([2, 1]));
    });
    expect(idsOf(result)).toEqual([2, 1]);
  });

  it("no se actualiza sola si no se indica un intervalo", async () => {
    client.listOrders.mockResolvedValue(pageOf([1]));

    renderHook(() => useOrders({}));
    await advance(0);
    await advance(60_000);

    expect(client.listOrders).toHaveBeenCalledTimes(1);
  });

  it("se pausa con la pestaña oculta y se actualiza al volver", async () => {
    client.listOrders.mockResolvedValue(pageOf([1]));
    const visibility = vi.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");

    renderHook(() => useOrders({}, { refreshInterval: INTERVAL }));
    await advance(0);
    await advance(INTERVAL * 3);
    expect(client.listOrders).toHaveBeenCalledTimes(1);

    visibility.mockReturnValue("visible");
    await act(async () => {
      document.dispatchEvent(new Event("visibilitychange"));
    });
    expect(client.listOrders).toHaveBeenCalledTimes(2);
  });

  it("conserva las órdenes si una actualización falla y se recupera en la siguiente", async () => {
    client.listOrders
      .mockResolvedValueOnce(pageOf([1]))
      .mockRejectedValueOnce(new Error("sin conexión"))
      .mockResolvedValueOnce(pageOf([3, 1]));

    const { result } = renderHook(() => useOrders({}, { refreshInterval: INTERVAL }));
    await advance(0);

    await advance(INTERVAL);
    expect(result.current.error.message).toBe("sin conexión");
    expect(idsOf(result)).toEqual([1]);
    expect(result.current.loading).toBe(false);

    await advance(INTERVAL);
    expect(result.current.error).toBeNull();
    expect(idsOf(result)).toEqual([3, 1]);
  });

  it("vuelve a pedir al cambiar los parámetros, conservando las órdenes mientras carga", async () => {
    client.listOrders.mockResolvedValue(pageOf([1]));

    const { result, rerender } = renderHook(({ page }) => useOrders({ page }), { initialProps: { page: 1 } });
    await advance(0);

    rerender({ page: 2 });
    expect(result.current.loading).toBe(true);
    expect(idsOf(result)).toEqual([1]);

    await advance(0);
    expect(client.listOrders).toHaveBeenLastCalledWith({ page: 2 });
    expect(result.current.loading).toBe(false);
  });

  it("vuelve a pedir la página al llamar a reload", async () => {
    client.listOrders.mockResolvedValue(pageOf([1]));

    const { result } = renderHook(() => useOrders({ page: 1 }));
    await advance(0);

    act(() => {
      result.current.reload();
    });
    await advance(0);

    expect(client.listOrders).toHaveBeenCalledTimes(2);
  });
});