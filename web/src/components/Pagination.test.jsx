// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import Pagination from "./Pagination.jsx";

afterEach(cleanup);

const button = (name) => screen.getByRole("button", { name });

describe("Pagination", () => {
  it("muestra la página actual y el total de órdenes", () => {
    render(<Pagination page={2} totalPages={5} totalCount={47} onChange={() => {}} />);

    expect(screen.getByText("Página 2 de 5 · 47 órdenes")).toBeTruthy();
  });

  it("usa el singular cuando hay una sola orden", () => {
    render(<Pagination page={1} totalPages={1} totalCount={1} onChange={() => {}} />);

    expect(screen.getByText("Página 1 de 1 · 1 orden")).toBeTruthy();
  });

  it("avisa la página a la que se quiere ir", () => {
    const onChange = vi.fn();
    render(<Pagination page={2} totalPages={5} totalCount={47} onChange={onChange} />);

    fireEvent.click(button("Siguiente"));
    fireEvent.click(button("Anterior"));

    expect(onChange).toHaveBeenNthCalledWith(1, 3);
    expect(onChange).toHaveBeenNthCalledWith(2, 1);
  });

  it("no deja retroceder en la primera página ni avanzar en la última", () => {
    const { rerender } = render(<Pagination page={1} totalPages={3} totalCount={25} onChange={() => {}} />);
    expect(button("Anterior").disabled).toBe(true);
    expect(button("Siguiente").disabled).toBe(false);

    rerender(<Pagination page={3} totalPages={3} totalCount={25} onChange={() => {}} />);
    expect(button("Anterior").disabled).toBe(false);
    expect(button("Siguiente").disabled).toBe(true);
  });

  it("indica que no hay resultados y bloquea ambos botones", () => {
    render(<Pagination page={1} totalPages={0} totalCount={0} onChange={() => {}} />);

    expect(screen.getByText("Sin resultados")).toBeTruthy();
    expect(button("Anterior").disabled).toBe(true);
    expect(button("Siguiente").disabled).toBe(true);
  });
});