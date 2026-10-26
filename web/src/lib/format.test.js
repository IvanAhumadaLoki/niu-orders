import { describe, expect, it } from "vitest";
import { formatClp, formatDateTime, formatTime } from "./format.js";

describe("formatClp", () => {
  it("formatea pesos chilenos con separador de miles y sin decimales", () => {
    // Se quitan los espacios porque algunos entornos insertan uno (a veces
    // irrompible) entre el símbolo y el número; lo que importa es el resto.
    expect(formatClp(22470).replace(/\s/g, "")).toBe("$22.470");
    expect(formatClp(1590).replace(/\s/g, "")).toBe("$1.590");
  });

  it("devuelve un guion si el valor no es un número", () => {
    expect(formatClp(undefined)).toBe("—");
    expect(formatClp(null)).toBe("—");
  });
});

describe("formatDateTime", () => {
  it("muestra día-mes-año y hora en la zona horaria indicada", () => {
    // 13:05 UTC es 10:05 en Santiago (UTC-3 en octubre).
    expect(formatDateTime("2026-10-26T13:05:00Z", "America/Santiago")).toBe("26-10-2026 10:05");
  });

  it("muestra la medianoche como 00:00 y no como 24:00", () => {
    expect(formatDateTime("2026-10-26T03:00:00Z", "America/Santiago")).toBe("26-10-2026 00:00");
  });

  it("devuelve un guion si falta la fecha o no es válida", () => {
    expect(formatDateTime(null)).toBe("—");
    expect(formatDateTime("no-es-una-fecha")).toBe("—");
  });
});

describe("formatTime", () => {
  it("muestra hora:minuto:segundo en la zona horaria indicada", () => {
    expect(formatTime(new Date("2026-10-26T13:05:09Z"), "America/Santiago")).toBe("10:05:09");
  });

  it("devuelve un guion si no hay una fecha válida", () => {
    expect(formatTime(null)).toBe("—");
    expect(formatTime(new Date("no-es-una-fecha"))).toBe("—");
  });
});