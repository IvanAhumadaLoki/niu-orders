import { describe, expect, it } from "vitest";
import { EMPTY_FILTERS, hasActiveFilters } from "./filters.js";

describe("hasActiveFilters", () => {
  it("es falso cuando no hay ningún filtro elegido", () => {
    expect(hasActiveFilters(EMPTY_FILTERS)).toBe(false);
  });

  it("es verdadero cuando hay al menos uno", () => {
    expect(hasActiveFilters({ ...EMPTY_FILTERS, dispatch_status: "error" })).toBe(true);
  });
});