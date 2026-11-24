import { describe, expect, it } from "vitest"
import { TRUCKS } from "../content/catalog"
import { layoutTruck, wheelAnchors } from "./layout"

describe("layoutTruck", () => {
  it("keeps every fictional truck in a drivable envelope", () => {
    for (const truck of TRUCKS) {
      const layout = layoutTruck(truck, 0, 0.38, 0.26)
      expect(layout.length).toBeGreaterThan(4.2)
      expect(layout.length).toBeLessThan(6.3)
      expect(layout.bed.length).toBeGreaterThan(0.8)
      expect(layout.cab.length).toBeGreaterThan(1)
      expect(layout.frontZ).toBeGreaterThan(layout.frontAxle)
      expect(layout.frontAxle).toBeGreaterThan(layout.rearAxle)
      expect(layout.rearAxle).toBeGreaterThan(layout.rearZ)
      expect(layout.bed.z1).toBeGreaterThan(layout.bed.z0)
      expect(layout.bodyY).toBeGreaterThan(0.15)
      const wheels = wheelAnchors(layout)
      expect(wheels).toHaveLength(4)
      for (const wheel of wheels) {
        expect(wheel.position[2]).toBeLessThan(layout.frontZ)
        expect(wheel.position[2]).toBeGreaterThan(layout.rearZ)
      }
    }
  })
})
