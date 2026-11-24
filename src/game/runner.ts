import type { Lane, Track, TrackEntity } from "../content/types"

export type RunStatus = "running" | "finished" | "crashed" | "bailed"

export type RunState = {
  z: number
  lane: Lane
  lanePos: number
  hits: number
  coins: number
  boost: number
  mud: number
  invuln: number
  elapsed: number
  status: RunStatus
  resolved: Record<string, true>
}

export type RunEvent = { type: "coin" | "hit" | "mud" | "boost" | "finish" | "crash" }

export type RunInput = { move: -1 | 0 | 1 }

export type RunPayout = {
  trackId: string
  distance: number
  hits: number
  coins: number
  finished: boolean
  clean: boolean
  status: Exclude<RunStatus, "running">
}

export function createRun(): RunState {
  return {
    z: 0,
    lane: 1,
    lanePos: 1,
    hits: 0,
    coins: 0,
    boost: 0,
    mud: 0,
    invuln: 0,
    elapsed: 0,
    status: "running",
    resolved: {},
  }
}

export function stepRun(
  state: RunState,
  track: Track,
  input: RunInput,
  dt: number,
): { state: RunState; events: RunEvent[] } {
  if (state.status !== "running") return { state, events: [] }
  const step = Math.min(Math.max(dt, 0), 0.05)
  let lane = state.lane
  if (input.move < 0) lane = Math.max(0, lane - 1) as Lane
  if (input.move > 0) lane = Math.min(2, lane + 1) as Lane
  const lanePos = state.lanePos + (lane - state.lanePos) * Math.min(1, step * 12)
  let speed = track.speed
  if (state.boost > 0) speed *= 1.45
  if (state.mud > 0) speed *= 0.6
  const nextZ = state.z + speed * step
  const resolved = { ...state.resolved }
  const events: RunEvent[] = []
  let hits = state.hits
  let coins = state.coins
  let boost = Math.max(0, state.boost - step)
  let mud = Math.max(0, state.mud - step)
  let invuln = Math.max(0, state.invuln - step)

  for (const entity of track.entities) {
    if (resolved[entity.id]) continue
    if (entity.z <= state.z || entity.z > nextZ) continue
    resolved[entity.id] = true
    if (entity.lane !== lane) continue
    const effect = applyEntity(entity)
    if (effect === "coin") {
      coins += 1
      events.push({ type: "coin" })
    } else if (effect === "mud") {
      mud = 1.15
      events.push({ type: "mud" })
    } else if (effect === "boost") {
      boost = 1.45
      events.push({ type: "boost" })
    } else if (invuln <= 0) {
      hits += 1
      invuln = 0.85
      events.push({ type: "hit" })
    }
  }

  let status: RunStatus = "running"
  let z = nextZ
  if (hits >= 3) {
    status = "crashed"
    events.push({ type: "crash" })
  } else if (z >= track.length) {
    z = track.length
    status = "finished"
    events.push({ type: "finish" })
  }

  return {
    state: {
      z,
      lane,
      lanePos,
      hits,
      coins,
      boost,
      mud,
      invuln,
      elapsed: state.elapsed + step,
      status,
      resolved,
    },
    events,
  }
}

function applyEntity(entity: TrackEntity): "coin" | "mud" | "boost" | "hit" {
  if (entity.kind === "coin") return "coin"
  if (entity.kind === "mud") return "mud"
  if (entity.kind === "boost") return "boost"
  return "hit"
}

export function bailRun(state: RunState): RunState {
  if (state.status !== "running") return state
  return { ...state, status: "bailed" }
}

export function settleRun(state: RunState, track: Track): RunPayout {
  const distance = Math.floor(state.z)
  const finished = state.status === "finished"
  const clean = finished && state.hits === 0
  const coins =
    state.coins * 10 + Math.floor(distance * 0.28) + (finished ? 120 : 0) + (clean ? 280 : 0)
  const status: RunPayout["status"] = state.status === "running" ? "bailed" : state.status
  return {
    trackId: track.id,
    distance,
    hits: state.hits,
    coins,
    finished,
    clean,
    status,
  }
}

export function previewCoins(state: RunState): number {
  return state.coins * 10 + Math.floor(state.z * 0.28)
}

export function hazardClusters(track: Track, window = 8): Lane[][] {
  const hazards = track.entities
    .filter((entity) => entity.kind === "rock" || entity.kind === "barrier")
    .slice()
    .sort((a, b) => a.z - b.z)
  const clusters: Lane[][] = []
  let current: TrackEntity[] = []
  for (const hazard of hazards) {
    const prev = current[current.length - 1]
    if (prev && hazard.z - prev.z > window) {
      clusters.push([...new Set(current.map((item) => item.lane))])
      current = []
    }
    current.push(hazard)
  }
  if (current.length) clusters.push([...new Set(current.map((item) => item.lane))])
  return clusters
}
