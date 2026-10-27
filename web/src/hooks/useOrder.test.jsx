// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { act, cleanup, renderHook } from "@testing-library/react";
import { client } from "../api/client.js";
import { useOrder } from "./useOrder.js";

// Se reemplaza el cliente de la API: estos tests miran qué se pide y cuándo.
vi.mock("../api/client.js", () => ({ client: { getOrder: vi.fn() } }));

// Deja pasar el tiempo (con temporizadores falsos) y resuelve lo que quede pendiente.
async function advance(ms) {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(ms);
  });
}

beforeEach(() => {
  vi.useFakeTimers();
  client.getOrder.mockReset();
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe("useOrder", () => {
  it("pide la orden por su ID y la expone", async () => {
    client.getOrder.mockResolvedValue({ id: 7, dispatch_status: "pending" });

    const { result } = renderHook(() => useOrder(7));
    expect(result.current.loading).toBe(true);
    expect(result.current.order).toBeNull();

    await advance(0);

    expect(client.getOrder).toHaveBeenCalledWith(7);
    expect(result.current.loading).toBe(false);
    expect(result.current.order).toEqual({ id: 7, dispatch_status: "pending" });
  });

  it("mantiene la orden al día con la actualización automática", async () => {
    client.getOrder
      .mockResolvedValueOnce({ id: 7, dispatch_status: "pending" })
      .mockResolvedValueOnce({ id: 7, dispatch_status: "sent" });

    const { result } = renderHook(() => useOrder(7, { refreshInterval: 5000 }));
    await advance(0);
    expect(result.current.order.dispatch_status).toBe("pending");

    await advance(5000);

    expect(client.getOrder).toHaveBeenCalledTimes(2);
    expect(result.current.order.dispatch_status).toBe("sent");
    expect(result.current.loading).toBe(false);
  });
});