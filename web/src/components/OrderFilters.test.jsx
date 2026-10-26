// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import OrderFilters from "./OrderFilters.jsx";
import { EMPTY_FILTERS } from "../lib/filters.js";

afterEach(cleanup);

// Textos de las opciones de un selector, en orden.
const optionTexts = (select) =>
  within(select)
    .getAllByRole("option")
    .map((option) => option.textContent);

describe("OrderFilters", () => {
  it("ofrece todas las opciones de cada filtro", () => {
    render(<OrderFilters filters={EMPTY_FILTERS} onChange={() => {}} />);

    expect(optionTexts(screen.getByLabelText("Estado de despacho"))).toEqual([
      "Todos",
      "Pendiente",
      "Enviado",
      "Error",
    ]);
    expect(optionTexts(screen.getByLabelText("Tienda"))).toEqual([
      "Todas",
      "Niu Foods Providencia",
      "Niu Foods Las Condes",
      "Niu Foods Ñuñoa",
    ]);
    expect(optionTexts(screen.getByLabelText("Tipo de pedido"))).toEqual(["Todos", "Retiro", "Delivery"]);
  });

  it("avisa el filtro elegido y conserva los demás", () => {
    const onChange = vi.fn();
    render(<OrderFilters filters={{ ...EMPTY_FILTERS, order_type: "delivery" }} onChange={onChange} />);

    fireEvent.change(screen.getByLabelText("Estado de despacho"), { target: { value: "sent" } });
    expect(onChange).toHaveBeenLastCalledWith({ dispatch_status: "sent", restaurant_id: "", order_type: "delivery" });

    fireEvent.change(screen.getByLabelText("Tienda"), { target: { value: "2" } });
    expect(onChange).toHaveBeenLastCalledWith({ dispatch_status: "", restaurant_id: "2", order_type: "delivery" });
  });

  it("«Limpiar filtros» solo se habilita si hay filtros activos, y los borra todos", () => {
    const onChange = vi.fn();
    const { rerender } = render(<OrderFilters filters={EMPTY_FILTERS} onChange={onChange} />);
    expect(screen.getByRole("button", { name: "Limpiar filtros" }).disabled).toBe(true);

    rerender(<OrderFilters filters={{ ...EMPTY_FILTERS, dispatch_status: "error" }} onChange={onChange} />);
    const clear = screen.getByRole("button", { name: "Limpiar filtros" });
    expect(clear.disabled).toBe(false);

    fireEvent.click(clear);
    expect(onChange).toHaveBeenCalledWith(EMPTY_FILTERS);
  });
});