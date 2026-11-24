export type Rarity = "common" | "rare" | "epic" | "legendary"

export type Slot =
  | "wheel"
  | "tire"
  | "lift"
  | "bumper"
  | "light"
  | "exhaust"
  | "spoiler"
  | "wrap"

export type WheelLook = {
  spokes: number
  spokeWidth: number
  spokeThick: number
  lip: number
  beadlock: boolean
  color: string
  metalness: number
  roughness: number
  turbine: boolean
}

export type TireLook = {
  radius: number
  width: number
  tread: "rib" | "allterrain" | "mud" | "paddle"
}

export type BumperKind = "factory" | "tube" | "winch" | "prerunner"
export type LightKind = "pods" | "bar" | "dual"
export type ExhaustKind = "stock" | "side" | "stack"
export type SpoilerKind = "none" | "lip" | "wing"
export type WrapKind = "clean" | "stripe" | "geo" | "sunset" | "circuit"

type PartBase = {
  id: string
  name: string
  rarity: Rarity
  blurb: string
  coins: number
  cores: number
}

export type Part =
  | (PartBase & { slot: "wheel"; look: WheelLook })
  | (PartBase & { slot: "tire"; look: TireLook })
  | (PartBase & { slot: "lift"; look: { inches: number; amount: number } })
  | (PartBase & { slot: "bumper"; look: { kind: BumperKind } })
  | (PartBase & { slot: "light"; look: { kind: LightKind } })
  | (PartBase & { slot: "exhaust"; look: { kind: ExhaustKind } })
  | (PartBase & { slot: "spoiler"; look: { kind: SpoilerKind } })
  | (PartBase & { slot: "wrap"; look: { kind: WrapKind; accent: string } })

export type Finish = {
  id: string
  name: string
  metalness: number
  roughness: number
  clearcoat: number
  clearcoatRoughness: number
  iridescence: number
}

export type Paint = {
  id: string
  name: string
  hex: string
}

export type TruckSpec = {
  id: string
  brand: string
  model: string
  role: string
  blurb: string
  paint: string
  plate: string
  wheelbase: number
  frontOverhang: number
  rearOverhang: number
  hoodLength: number
  cabLength: number
  width: number
  track: number
  cabHeight: number
  bedWall: number
  stance: number
  rake: number
  flare: number
  roof: "flat" | "fastback"
  fascia: "bars" | "slots" | "grid" | "slit"
  lamps: "round" | "rect" | "blade"
  cage: boolean
  intake: boolean
  rack: boolean
  skirt: boolean
  scoop: boolean
  fit?: { y?: number; scale?: number; rotY?: number }
}

export type Loadout = {
  paint: string
  finish: string
  wheel: string
  tire: string
  lift: string
  bumper: string
  light: string
  exhaust: string
  spoiler: string
  wrap: string
}

export type CategoryId = "paint" | Slot

export type Product = {
  id: string
  title: string
  detail: string
  priceLabel: string
  kind: "consumable" | "nonconsumable"
  grants: {
    cores?: number
    coins?: number
    partIds?: string[]
  }
}

export type QuestMetric =
  | "runs"
  | "clean"
  | "bestCoins"
  | "bestDistance"
  | "gulch"
  | "parts"
  | "dailies"

export type Quest = {
  id: string
  title: string
  detail: string
  metric: QuestMetric
  goal: number
  rewardCoins?: number
  rewardPartId?: string
  duplicateCoins?: number
}

export type DailyReward = {
  label: string
  coins?: number
  partId?: string
  duplicateCoins?: number
}

export type Lane = 0 | 1 | 2

export type TrackEntity = {
  id: string
  kind: "coin" | "rock" | "barrier" | "mud" | "boost"
  lane: Lane
  z: number
}

export type Track = {
  id: string
  name: string
  blurb: string
  length: number
  speed: number
  unlockFinishes: number
  entities: TrackEntity[]
}
