import { describe, expect, it } from "vitest"
import { partById } from "../content/catalog"
import {
  applyRun,
  buyPart,
  claimDaily,
  defaultPersisted,
  equipPart,
  grantProduct,
  normalize,
  restorePurchases,
} from "./logic"
import type { RunPayout } from "./runner"

function payout(patch: Partial<RunPayout> = {}): RunPayout {
  return {
    trackId: "switchback",
    distance: 200,
    hits: 1,
    coins: 180,
    finished: false,
    clean: false,
    status: "crashed",
    ...patch,
  }
}

describe("economy", () => {
  it("starts with coins, no cores, and the free parts", () => {
    const state = defaultPersisted()
    expect(state.coins).toBe(750)
    expect(state.cores).toBe(0)
    expect(state.owned).toContain("wh-five")
    expect(state.owned).not.toContain("wh-deep")
  })

  it("buys with coins, equips, and refuses a second buy", () => {
    const bought = buyPart(defaultPersisted(), "ti-at", "coins")
    expect(bought.error).toBeUndefined()
    expect(bought.state.coins).toBe(760)
    expect(bought.state.owned).toContain("ti-at")
    expect(bought.state.loadouts[bought.state.truckId]?.tire).toBe("ti-at")
    expect(bought.state.stats.partsBought).toBe(1)
    expect(buyPart(bought.state, "ti-at", "coins").error).toMatch(/garage/i)
  })

  it("refuses a purchase the balance can't cover", () => {
    const result = buyPart(defaultPersisted(), "wh-turbine", "coins")
    expect(result.error).toMatch(/coins/i)
    expect(result.state.coins).toBe(750)
  })

  it("spends cores and leaves coins alone", () => {
    const rich = { ...defaultPersisted(), cores: 20 }
    const bought = buyPart(rich, "wh-deep", "cores")
    expect(bought.state.cores).toBe(6)
    expect(bought.state.coins).toBe(1000)
    expect(bought.state.owned).toContain("wh-deep")
  })

  it("does not equip a locked part", () => {
    const result = equipPart(defaultPersisted(), "wh-deep")
    expect(result.error).toBeTruthy()
  })

  it("banks a run and unlocks the shake-down quest once", () => {
    const first = applyRun(defaultPersisted(), payout({ distance: 80, coins: 120 }))
    expect(first.state.coins).toBe(1270)
    expect(first.state.stats.runs).toBe(1)
    expect(first.state.questRewarded).toContain("shake")
    expect(first.toasts.some((toast) => toast.includes("400"))).toBe(true)
    const second = applyRun(first.state, payout({ distance: 90, coins: 100 }))
    expect(second.state.questRewarded.filter((id) => id === "shake")).toHaveLength(1)
  })

  it("grants a part for a clean finish and pays coins if it is already owned", () => {
    const run = payout({
      distance: 1120,
      hits: 0,
      coins: 800,
      finished: true,
      clean: true,
      status: "finished",
    })
    const clean = applyRun(defaultPersisted(), run)
    expect(clean.state.owned).toContain("ex-side")
    const already = defaultPersisted()
    const owned = { ...already, owned: [...already.owned, "ex-side"] }
    const duplicate = applyRun(owned, run)
    expect(duplicate.toasts.some((toast) => toast.includes("already"))).toBe(true)
    expect(duplicate.state.owned.filter((id) => id === "ex-side")).toHaveLength(1)
  })

  it("claims a daily once and continues a streak", () => {
    const first = claimDaily(defaultPersisted(), "2026-11-24")
    expect(first.state.stats.streak).toBe(1)
    expect(first.state.coins).toBe(950)
    expect(claimDaily(first.state, "2026-11-24").error).toMatch(/already/i)
    const next = claimDaily(first.state, "2026-11-25")
    expect(next.state.stats.streak).toBe(2)
    const skipped = claimDaily(first.state, "2026-11-27")
    expect(skipped.state.stats.streak).toBe(1)
  })

  it("grants a core pack repeatedly and a kit only once", () => {
    const cores = grantProduct(defaultPersisted(), "cores_small", "tx-1", "2026-11-24T00:00:00.000Z")
    expect(cores.state.cores).toBe(80)
    const again = grantProduct(cores.state, "cores_small", "tx-2", "2026-11-24T00:00:00.000Z")
    expect(again.state.cores).toBe(160)
    const kit = grantProduct(again.state, "bundle_trail", "tx-3", "2026-11-24T00:00:00.000Z")
    expect(kit.state.owned).toEqual(expect.arrayContaining(["wh-deep", "ti-mud", "lf-4"]))
    expect(grantProduct(kit.state, "bundle_trail", "tx-4", "2026-11-24T00:00:00.000Z").error).toMatch(/own/i)
  })

  it("restores kit parts from receipts without duplicating cores", () => {
    const bought = grantProduct(defaultPersisted(), "bundle_night", "tx-9", "2026-11-24T00:00:00.000Z")
    const stripped = { ...bought.state, owned: bought.state.owned.filter((id) => id !== "lt-dual") }
    const restored = restorePurchases(stripped)
    expect(restored.state.owned).toContain("lt-dual")
    const cores = grantProduct(defaultPersisted(), "cores_small", "tx-c", "2026-11-24T00:00:00.000Z")
    const wiped = { ...cores.state, cores: 0 }
    expect(restorePurchases(wiped).state.cores).toBe(0)
  })

  it("repairs a corrupt save without dropping the free garage", () => {
    const fixed = normalize({ coins: -4, truckId: "nope", owned: ["wh-deep", 12], sound: true })
    expect(fixed.coins).toBe(0)
    expect(fixed.truckId).toBe("ridgehaul-summit")
    expect(fixed.owned).toContain("wh-five")
    expect(fixed.owned).toContain("wh-deep")
    expect(fixed.sound).toBe(true)
    expect(partById("wh-deep")).toBeTruthy()
  })
})
