// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import RefreshControls from "./RefreshControls.jsx";

afterEach(cleanup);

const baseProps = { auto: true, onAutoChange: () => {}, onRefresh: () => {}, loading: false, updatedAt: null };

describe("RefreshControls", () => {
  it("refleja si la actualización automática está activa y avisa al cambiarla", () => {
    const onAutoChange = vi.fn();
    render(<RefreshControls {...baseProps} onAutoChange={onAutoChange} />);

    const checkbox = screen.getByLabelText(/Actualizar automáticamente/);
    expect(checkbox.checked).toBe(true);

    fireEvent.click(checkbox);
    expect(onAutoChange).toHaveBeenCalledWith(false);
  });

  it("actualiza a mano al pulsar el botón", () => {
    const onRefresh = vi.fn();
    render(<RefreshControls {...baseProps} onRefresh={onRefresh} />);

    fireEvent.click(screen.getByRole("button", { name: "Actualizar" }));

    expect(onRefresh).toHaveBeenCalledTimes(1);
  });

  it("bloquea el botón mientras hay una carga en curso", () => {
    render(<RefreshControls {...baseProps} loading />);

    expect(screen.getByRole("button", { name: "Actualizar" }).disabled).toBe(true);
  });

  it("muestra la hora de la última actualización, o que aún no hay ninguna", () => {
    const { rerender } = render(<RefreshControls {...baseProps} />);
    expect(screen.getByText("Sin actualizar aún")).toBeTruthy();

    // La hora exacta depende de la zona horaria de quien ejecuta los tests:
    // solo se comprueba su forma (hora:minuto:segundo).
    rerender(<RefreshControls {...baseProps} updatedAt={new Date("2026-10-26T13:05:09Z")} />);
    expect(screen.getByText(/^Actualizado a las \d{2}:\d{2}:\d{2}$/)).toBeTruthy();
  });
});