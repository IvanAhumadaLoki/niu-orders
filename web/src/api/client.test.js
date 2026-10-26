import { describe, expect, it } from "vitest";
import { ApiError, createClient } from "./client.js";

const BASE_URL = "http://api.test";

// Respuesta JSON de mentira, como la que devolvería fetch.
function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Cliente con un fetch falso: guarda lo que se pidió y responde lo que devuelva `responder`.
function clientWith(responder) {
  const requests = [];
  const fetchImpl = async (url, options) => {
    requests.push({ url: url.toString(), options });
    return responder();
  };
  return { client: createClient({ baseUrl: BASE_URL, fetchImpl }), requests };
}

describe("client.listOrders", () => {
  it("pide el listado con los filtros y omite los valores vacíos", async () => {
    const { client, requests } = clientWith(() => jsonResponse(200, { data: [], meta: {} }));

    await client.listOrders({
      page: 2,
      dispatch_status: "sent",
      order_type: "",
      restaurant_id: undefined,
      per_page: null,
    });

    expect(requests[0].url).toBe("http://api.test/api/v1/orders?page=2&dispatch_status=sent");
    expect(requests[0].options.headers.Accept).toBe("application/json");
  });

  it("devuelve el JSON de la respuesta", async () => {
    const payload = { data: [{ id: 1 }], meta: { total_count: 1 } };
    const { client } = clientWith(() => jsonResponse(200, payload));

    expect(await client.listOrders()).toEqual(payload);
  });

  it("convierte un 422 en un ApiError con el código y el detalle por campo", async () => {
    const { client } = clientWith(() =>
      jsonResponse(422, {
        error: {
          code: "validation_failed",
          message: "Los datos enviados no son válidos",
          details: { page: ["debe ser un entero mayor que 0"] },
        },
      }),
    );

    await expect(client.listOrders({ page: 0 })).rejects.toMatchObject({
      name: "ApiError",
      status: 422,
      code: "validation_failed",
      message: "Los datos enviados no son válidos",
      details: { page: ["debe ser un entero mayor que 0"] },
    });
  });

  it("distingue una API caída de una respuesta de error", async () => {
    const fetchImpl = async () => {
      throw new TypeError("Failed to fetch");
    };
    const client = createClient({ baseUrl: BASE_URL, fetchImpl });

    const error = await client.listOrders().catch((e) => e);

    expect(error).toBeInstanceOf(ApiError);
    expect(error).toMatchObject({ code: "network_error", status: null });
  });

  it("no se rompe si el error no viene en JSON", async () => {
    const { client } = clientWith(() => new Response("<html>Error</html>", { status: 500 }));

    await expect(client.listOrders()).rejects.toMatchObject({
      status: 500,
      code: null,
      message: "La API respondió 500",
    });
  });
});

describe("client.getOrder", () => {
  it("pide el detalle de la orden por su ID", async () => {
    const { client, requests } = clientWith(() => jsonResponse(200, { id: 5 }));

    const order = await client.getOrder(5);

    expect(requests[0].url).toBe("http://api.test/api/v1/orders/5");
    expect(order).toEqual({ id: 5 });
  });

  it("convierte un 404 en un ApiError", async () => {
    const { client } = clientWith(() =>
      jsonResponse(404, { error: { code: "not_found", message: "No existe la orden 999" } }),
    );

    await expect(client.getOrder(999)).rejects.toMatchObject({ status: 404, code: "not_found" });
  });
});