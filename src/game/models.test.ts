import { describe, expect, it } from "vitest"
import { findModelUrl } from "./models"

describe("findModelUrl", () => {
  it("matches a dropped glb by truck or part id", () => {
    const files = {
      "../assets/models/trucks/ridgehaul-summit.glb": "/assets/summit.glb",
      "../assets/models/parts/wh-mesh.glb": "/assets/mesh.glb",
    }
    expect(findModelUrl(files, "trucks", "ridgehaul-summit")).toBe("/assets/summit.glb")
    expect(findModelUrl(files, "parts", "wh-mesh")).toBe("/assets/mesh.glb")
    expect(findModelUrl(files, "trucks", "missing")).toBeUndefined()
  })
})
