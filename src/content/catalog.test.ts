import { describe, expect, it } from "vitest"
import { PARTS, TRUCKS, isFreePart, paintById, partById } from "./catalog"
import { PRODUCTS } from "./products"
import { QUESTS } from "./quests"
import { TRACKS } from "./tracks"

describe("catalog", () => {
  it("ships at least 25 parts and four fictional trucks", () => {
    expect(PARTS.length).toBeGreaterThanOrEqual(25)
    expect(TRUCKS).toHaveLength(4)
    expect(new Set(PARTS.map((part) => part.id)).size).toBe(PARTS.length)
    expect(new Set(TRUCKS.map((truck) => truck.id)).size).toBe(TRUCKS.length)
  })

  it("gives every paid part a coin price so it can be earned", () => {
    for (const part of PARTS) {
      if (part.rarity !== "common") expect(part.coins).toBeGreaterThan(0)
      if (part.coins > 0) expect(part.cores).toBeGreaterThan(0)
      if (isFreePart(part)) expect(part.rarity).toBe("common")
    }
  })

  it("keeps store kits as named parts that also have coin prices", () => {
    for (const product of PRODUCTS) {
      for (const id of product.grants.partIds ?? []) {
        const part = partById(id)
        expect(part, id).toBeTruthy()
        expect(part?.coins).toBeGreaterThan(0)
      }
    }
  })

  it("points quests and truck paints at real ids", () => {
    for (const quest of QUESTS) {
      if (quest.rewardPartId) expect(partById(quest.rewardPartId)?.coins).toBeGreaterThan(0)
    }
    for (const truck of TRUCKS) expect(paintById(truck.paint)).toBeTruthy()
  })

  it("uses two distinct tracks", () => {
    expect(TRACKS.map((track) => track.id)).toEqual(["switchback", "gulch"])
  })
})
