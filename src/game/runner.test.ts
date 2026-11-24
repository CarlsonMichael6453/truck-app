import { describe, expect, it } from "vitest"
import { TRACKS } from "../content/tracks"
import { createRun, hazardClusters, settleRun, stepRun } from "./runner"

describe("runner", () => {
  it("keeps a safe lane in every hazard cluster", () => {
    for (const track of TRACKS) {
      const ids = track.entities.map((entity) => entity.id)
      expect(new Set(ids).size).toBe(ids.length)
      for (const cluster of hazardClusters(track)) {
        expect(cluster.length).toBeLessThan(3)
      }
      for (const entity of track.entities) {
        expect(entity.z).toBeGreaterThan(20)
        expect(entity.z).toBeLessThan(track.length)
      }
    }
  })

  it("changes lanes once per input and pays a clean finish", () => {
    const track = TRACKS[0]!
    let state = createRun()
    const moved = stepRun(state, track, { move: -1 }, 0.016)
    expect(moved.state.lane).toBe(0)
    state = moved.state
    const held = stepRun(state, track, { move: 0 }, 0.016)
    expect(held.state.lane).toBe(0)

    state = { ...createRun(), z: track.length - 1, status: "running" }
    const finished = stepRun(state, track, { move: 0 }, 0.2)
    expect(finished.state.status).toBe("finished")
    const payout = settleRun(finished.state, track)
    expect(payout.clean).toBe(true)
    expect(payout.coins).toBeGreaterThan(120)
  })

  it("counts a rock only in the truck's lane and then grants invulnerability", () => {
    const track = {
      ...TRACKS[0]!,
      entities: [
        { id: "a", kind: "rock" as const, lane: 1 as const, z: 1 },
        { id: "b", kind: "rock" as const, lane: 1 as const, z: 2 },
        { id: "c", kind: "rock" as const, lane: 0 as const, z: 1.5 },
      ],
      length: 100,
      speed: 80,
    }
    const first = stepRun(createRun(), track, { move: 0 }, 0.3)
    expect(first.events.some((event) => event.type === "hit")).toBe(true)
    expect(first.state.hits).toBe(1)
  })
})
