import type { TruckSpec } from "./types"

export type Fit = {
  clearance: number
  belt: number
  roof: number
  cabFront: number
  cabRear: number
}

/** Matches the stations in tools/build_trucks.py so parts sit on the mesh. */
export const TRUCK_FIT: Record<string, Fit> = {
  "ridgehaul-summit": { clearance: 0.26, belt: 0.96, roof: 1.58, cabFront: 1.18, cabRear: -0.42 },
  "veldt-meridian": { clearance: 0.32, belt: 1.04, roof: 1.7, cabFront: 1.05, cabRear: 0.05 },
  "northline-harbor": { clearance: 0.28, belt: 1.0, roof: 1.82, cabFront: 0.92, cabRear: -0.28 },
  "kestrel-talon": { clearance: 0.22, belt: 0.9, roof: 1.36, cabFront: 0.95, cabRear: -0.15 },
}

export type Vec3 = [number, number, number]

export type TruckAnchors = {
  wheels: Array<{ id: string; position: Vec3 }>
  bumperFront: Vec3
  bumperRear: Vec3
  lightbar: Vec3
  exhaust: Vec3
  spoiler: Vec3
}

export function anchorsFor(spec: TruckSpec): TruckAnchors {
  const fit = TRUCK_FIT[spec.id] ?? TRUCK_FIT["ridgehaul-summit"]!
  const front = spec.wheelbase / 2
  const rear = -front
  const frontZ = front + spec.frontOverhang
  const rearZ = rear - spec.rearOverhang
  const half = spec.track / 2
  const wheelY = 0.38
  return {
    wheels: [
      { id: "fl", position: [-half, wheelY, front] },
      { id: "fr", position: [half, wheelY, front] },
      { id: "rl", position: [-half, wheelY, rear] },
      { id: "rr", position: [half, wheelY, rear] },
    ],
    bumperFront: [0, fit.clearance + 0.18, frontZ - 0.02],
    bumperRear: [0, fit.clearance + 0.2, rearZ + 0.04],
    lightbar: [0, fit.roof + 0.04, fit.cabFront - 0.05],
    exhaust: [spec.width * 0.28, fit.clearance + 0.08, rearZ + 0.12],
    spoiler: [0, fit.belt * 0.55 + 0.28, rearZ + 0.22],
  }
}
