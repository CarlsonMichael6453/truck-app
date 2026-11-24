import type { TruckSpec } from "../content/types"

export type Vec3 = [number, number, number]

export type TruckLayout = {
  frontZ: number
  rearZ: number
  frontAxle: number
  rearAxle: number
  width: number
  track: number
  cab: { z0: number; z1: number; height: number; length: number }
  hood: { z0: number; z1: number; length: number }
  bed: { z0: number; z1: number; wall: number; length: number }
  bodyY: number
  wheelY: number
  archLocalY: number
  tireRadius: number
  tireWidth: number
  lift: number
  flare: number
  length: number
}

const PLANTED_BASE = 0.3

export function layoutTruck(
  spec: TruckSpec,
  lift: number,
  tireRadius: number,
  tireWidth: number,
): TruckLayout {
  const frontAxle = spec.wheelbase / 2
  const rearAxle = -frontAxle
  const frontZ = frontAxle + spec.frontOverhang
  const rearZ = rearAxle - spec.rearOverhang
  const hoodZ1 = frontZ - 0.14
  const hoodZ0 = hoodZ1 - spec.hoodLength
  const cabZ1 = hoodZ0 + 0.16
  const cabZ0 = cabZ1 - spec.cabLength
  const bedZ1 = cabZ0 + 0.02
  const bedZ0 = rearZ + 0.16
  const tireDelta = tireRadius - 0.38
  const planted = PLANTED_BASE + spec.stance + tireDelta
  const bodyY = planted + lift
  const wheelY = tireRadius
  return {
    frontZ,
    rearZ,
    frontAxle,
    rearAxle,
    width: spec.width,
    track: spec.track,
    cab: { z0: cabZ0, z1: cabZ1, height: spec.cabHeight, length: cabZ1 - cabZ0 },
    hood: { z0: hoodZ0, z1: hoodZ1, length: hoodZ1 - hoodZ0 },
    bed: { z0: bedZ0, z1: bedZ1, wall: spec.bedWall, length: bedZ1 - bedZ0 },
    bodyY,
    wheelY,
    archLocalY: wheelY - planted,
    tireRadius,
    tireWidth,
    lift,
    flare: spec.flare,
    length: frontZ - rearZ,
  }
}

export function wheelAnchors(layout: TruckLayout): Array<{ id: string; position: Vec3 }> {
  const half = layout.track / 2
  return [
    { id: "fl", position: [-half, layout.wheelY, layout.frontAxle] },
    { id: "fr", position: [half, layout.wheelY, layout.frontAxle] },
    { id: "rl", position: [-half, layout.wheelY, layout.rearAxle] },
    { id: "rr", position: [half, layout.wheelY, layout.rearAxle] },
  ]
}
