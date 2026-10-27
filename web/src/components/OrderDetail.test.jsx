// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import OrderDetail from "./OrderDetail.jsx";
import { detailedOrder } from "../test/fixtures.js";

afterEach(cleanup);

const baseProps = {
  orderId: 32,
  order: detailedOrder,
  loading: false,
  error: null,
  onClose: () => {},
  onRetry: () => {},
};

// Texto de la definición (<dd>) que acompaña a un título (<dt>).
const valueOf = (label) => screen.getByText(label).nextElementSibling.textContent;

describe("OrderDetail", () => {
  it("muestra el resumen, el cliente, los productos y el despacho", () => {
    render(<OrderDetail {...baseProps} />);

    expect(screen.getByRole("dialog", { name: "Orden #32" })).toBeTruthy();
    expect(screen.getByText("Enviado")).toBeTruthy();

    // Resumen
    expect(screen.getByText("Niu Foods Las Condes")).toBeTruthy();
    expect(screen.getByText("Delivery")).toBeTruthy();

    // Cliente
    expect(screen.getByText("Ana Pérez")).toBeTruthy();
    expect(screen.getByText("+56912345678")).toBeTruthy();
    expect(valueOf("Dirección de entrega")).toBe("Av. Providencia 1234, Santiago");

    // Productos: nombre y SKU, precio unitario y subtotal
    expect(screen.getByText("Niu Roll Salmón")).toBeTruthy();
    expect(screen.getByText(/SKU-001/)).toBeTruthy();
    expect(screen.getByText(/8\.990/)).toBeTruthy();
    expect(screen.getByText(/17\.980/)).toBeTruthy();
    // El total aparece en el resumen y al pie de la tabla.
    expect(screen.getAllByText(/22\.470/)).toHaveLength(2);

    // Despacho
    expect(valueOf("Intentos")).toBe("2");
    expect(valueOf("Fecha de envío")).toMatch(/^\d{2}-\d{2}-\d{4} \d{2}:\d{2}$/);
    expect(screen.queryByText("Último error")).toBeNull();
  });

  it("en un pedido de retiro no muestra dirección", () => {
    render(<OrderDetail {...baseProps} order={{ ...detailedOrder, order_type: "pickup", delivery_address: null }} />);

    expect(screen.getByText("Retiro")).toBeTruthy();
    expect(valueOf("Entrega")).toBe("Retiro en tienda");
    expect(screen.queryByText(/Providencia 1234/)).toBeNull();
  });

  it("muestra los intentos y el último error cuando el despacho falló", () => {
    const failed = {
      ...detailedOrder,
      dispatch_status: "error",
      dispatch_attempts: 6,
      dispatched_at: null,
      last_dispatch_error: "Se agotaron los reintentos",
    };

    render(<OrderDetail {...baseProps} order={failed} />);

    expect(screen.getByText("Error")).toBeTruthy();
    expect(valueOf("Intentos")).toBe("6");
    expect(valueOf("Fecha de envío")).toBe("—");
    expect(valueOf("Último error")).toBe("Se agotaron los reintentos");
  });

  it("indica que está cargando mientras no hay datos", () => {
    render(<OrderDetail {...baseProps} order={null} loading />);

    expect(screen.getByRole("dialog", { name: "Orden #32" })).toBeTruthy();
    expect(screen.getByText("Cargando detalle…")).toBeTruthy();
  });

  it("muestra el error y permite reintentar cuando no hay datos", () => {
    const onRetry = vi.fn();
    render(<OrderDetail {...baseProps} order={null} error={new Error("La API respondió 500")} onRetry={onRetry} />);

    expect(screen.getByText("La API respondió 500")).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Reintentar" }));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });

  it("conserva los datos a la vista cuando una actualización falla", () => {
    render(<OrderDetail {...baseProps} error={new Error("No se pudo conectar con la API")} />);

    expect(screen.getByText("No se pudo conectar con la API")).toBeTruthy();
    expect(screen.getByText("Ana Pérez")).toBeTruthy();
  });

  it("enfoca el botón de cierre al abrirse", () => {
    render(<OrderDetail {...baseProps} />);

    expect(document.activeElement).toBe(screen.getByRole("button", { name: "Cerrar detalle" }));
  });

  it("se cierra con el botón y con la tecla Esc", () => {
    const onClose = vi.fn();
    render(<OrderDetail {...baseProps} onClose={onClose} />);

    fireEvent.click(screen.getByRole("button", { name: "Cerrar detalle" }));
    expect(onClose).toHaveBeenCalledTimes(1);

    fireEvent.keyDown(document, { key: "Escape" });
    expect(onClose).toHaveBeenCalledTimes(2);

    // Otras teclas no lo cierran.
    fireEvent.keyDown(document, { key: "Enter" });
    expect(onClose).toHaveBeenCalledTimes(2);
  });

  it("se cierra al hacer clic fuera del panel, pero no al hacer clic dentro", () => {
    const onClose = vi.fn();
    const { container } = render(<OrderDetail {...baseProps} onClose={onClose} />);

    fireEvent.click(screen.getByRole("dialog"));
    expect(onClose).not.toHaveBeenCalled();

    fireEvent.click(container.querySelector(".overlay"));
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});