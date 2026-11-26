import type { Finish, Loadout, Paint, Part, Rarity, Slot, TruckSpec } from "./types"

export const RARITY_COLOR: Record<Rarity, string> = {
  common: "#b7c0cc",
  rare: "#7eb6ff",
  epic: "#c99bff",
  legendary: "#f2c56e",
}

export const PAINTS: Paint[] = [
  { id: "copper", name: "Kiln Copper", hex: "#c4622d" },
  { id: "ivory", name: "Bone Ivory", hex: "#e6e0d4" },
  { id: "ink", name: "Night Ink", hex: "#1b1e26" },
  { id: "sage", name: "Sage Alloy", hex: "#7e8d72" },
  { id: "sea", name: "Harbor Teal", hex: "#1d6e76" },
  { id: "sand", name: "Dune Sand", hex: "#c4a56d" },
  { id: "crimson", name: "Brake Crimson", hex: "#8d2e2e" },
  { id: "ice", name: "Glacier", hex: "#c5d0dc" },
  { id: "violet", name: "Signal Violet", hex: "#3d2b58" },
  { id: "lime", name: "Pit Lime", hex: "#c6d24a" },
  { id: "porcelain", name: "Porcelain", hex: "#f4f4f1" },
  { id: "switch", name: "Switchback", hex: "#e36b2c" },
]

export const FINISHES: Finish[] = [
  { id: "gloss", name: "Gloss", metalness: 0.12, roughness: 0.18, clearcoat: 1, clearcoatRoughness: 0.06, iridescence: 0 },
  { id: "metallic", name: "Metallic", metalness: 0.86, roughness: 0.28, clearcoat: 0.7, clearcoatRoughness: 0.12, iridescence: 0 },
  { id: "matte", name: "Matte", metalness: 0.04, roughness: 0.82, clearcoat: 0.02, clearcoatRoughness: 0.55, iridescence: 0 },
  { id: "satin", name: "Satin", metalness: 0.42, roughness: 0.45, clearcoat: 0.32, clearcoatRoughness: 0.24, iridescence: 0 },
  { id: "pearl", name: "Pearl", metalness: 0.24, roughness: 0.16, clearcoat: 1, clearcoatRoughness: 0.04, iridescence: 1 },
]

export const TRUCKS: TruckSpec[] = [
  {
    id: "ridgehaul-summit",
    brand: "Ridgehaul",
    model: "Summit",
    role: "Half-ton",
    blurb: "The half-ton you take when the day is ordinary and the road is not.",
    paint: "copper",
    plate: "SMIT 150",
    wheelbase: 3.4,
    frontOverhang: 0.78,
    rearOverhang: 0.78,
    hoodLength: 1.05,
    cabLength: 2.15,
    width: 1.86,
    track: 1.56,
    cabHeight: 1.02,
    bedWall: 0.46,
    stance: 0,
    rake: 0.4,
    flare: 0.05,
    roof: "flat",
    fascia: "bars",
    lamps: "round",
    cage: false,
    intake: false,
    rack: false,
    skirt: false,
    scoop: false,
  },
  {
    id: "veldt-meridian",
    brand: "Veldt",
    model: "Meridian",
    role: "Desert hauler",
    blurb: "A long bed and tall arches for sand that never agreed to be a road.",
    paint: "sand",
    plate: "VLDT 4",
    wheelbase: 3.55,
    frontOverhang: 0.86,
    rearOverhang: 1.15,
    hoodLength: 1.1,
    cabLength: 1.45,
    width: 1.98,
    track: 1.7,
    cabHeight: 1.08,
    bedWall: 0.4,
    stance: 0.06,
    rake: 0.34,
    flare: 0.14,
    roof: "flat",
    fascia: "slots",
    lamps: "rect",
    cage: true,
    intake: true,
    rack: false,
    skirt: false,
    scoop: true,
  },
  {
    id: "northline-harbor",
    brand: "Northline",
    model: "Harbor",
    role: "City utility",
    blurb: "Upright cab, square corners, happier with a ladder than a trophy.",
    paint: "ice",
    plate: "HBR 220",
    wheelbase: 3.2,
    frontOverhang: 0.7,
    rearOverhang: 0.9,
    hoodLength: 0.7,
    cabLength: 1.95,
    width: 1.82,
    track: 1.52,
    cabHeight: 1.24,
    bedWall: 0.52,
    stance: 0.02,
    rake: 0.16,
    flare: 0.03,
    roof: "flat",
    fascia: "grid",
    lamps: "rect",
    cage: false,
    intake: false,
    rack: true,
    skirt: false,
    scoop: false,
  },
  {
    id: "kestrel-talon",
    brand: "Kestrel",
    model: "Talon",
    role: "Sport truck",
    blurb: "Low roof, long hood, and no interest in staying behind anything.",
    paint: "violet",
    plate: "TLN X",
    wheelbase: 3.15,
    frontOverhang: 0.95,
    rearOverhang: 0.58,
    hoodLength: 1.25,
    cabLength: 1.8,
    width: 1.94,
    track: 1.66,
    cabHeight: 0.84,
    bedWall: 0.34,
    stance: -0.05,
    rake: 0.58,
    flare: 0.09,
    roof: "fastback",
    fascia: "slit",
    lamps: "blade",
    cage: false,
    intake: false,
    rack: false,
    skirt: true,
    scoop: false,
  },
]

export const PARTS: Part[] = [
  { id: "wh-steel", slot: "wheel", name: "Steel Dish", rarity: "common", blurb: "Plain stamped steel. Honest, heavy, easy to hose off.", coins: 0, cores: 0, look: { spokes: 8, spokeWidth: 0.03, spokeThick: 0.025, lip: 0, beadlock: false, color: "#8d939c", metalness: 0.7, roughness: 0.38, turbine: false } },
  { id: "wh-five", slot: "wheel", name: "Five-Spoke", rarity: "common", blurb: "Five thick spokes. The look the Summit leaves the bay with.", coins: 0, cores: 0, look: { spokes: 5, spokeWidth: 0.055, spokeThick: 0.03, lip: 0.15, beadlock: false, color: "#d5dde6", metalness: 0.95, roughness: 0.18, turbine: false } },
  { id: "wh-deep", slot: "wheel", name: "Deep Lip", rarity: "rare", blurb: "A polished outer lip that catches the bay lights.", coins: 980, cores: 14, look: { spokes: 5, spokeWidth: 0.04, spokeThick: 0.025, lip: 1, beadlock: false, color: "#e7edf4", metalness: 1, roughness: 0.08, turbine: false } },
  { id: "wh-bead", slot: "wheel", name: "Beadlock", rarity: "rare", blurb: "A bolted ring for airing down without the tire walking off.", coins: 1180, cores: 16, look: { spokes: 6, spokeWidth: 0.045, spokeThick: 0.03, lip: 0.2, beadlock: true, color: "#3a3e46", metalness: 0.75, roughness: 0.32, turbine: false } },
  { id: "wh-mesh", slot: "wheel", name: "Forged Mesh", rarity: "epic", blurb: "A dense mesh face, machined rather than cast.", coins: 2500, cores: 34, look: { spokes: 12, spokeWidth: 0.018, spokeThick: 0.02, lip: 0.45, beadlock: false, color: "#c9d2dc", metalness: 1, roughness: 0.12, turbine: false } },
  { id: "wh-turbine", slot: "wheel", name: "Solar Turbine", rarity: "legendary", blurb: "Twisted spokes with a warm metal that looks lit from inside.", coins: 5400, cores: 70, look: { spokes: 7, spokeWidth: 0.05, spokeThick: 0.028, lip: 0.7, beadlock: false, color: "#e3c07a", metalness: 1, roughness: 0.14, turbine: true } },
  { id: "wh-aero", slot: "wheel", name: "Aero Lattice", rarity: "epic", blurb: "Thin spokes and two hoops. A mesh you can see the caliper through.", coins: 3050, cores: 42, look: { spokes: 14, spokeWidth: 0.006, spokeThick: 0.005, lip: 0.4, beadlock: false, color: "#d7dee6", metalness: 1, roughness: 0.1, turbine: false } },
  { id: "wh-blade", slot: "wheel", name: "Vector Blade", rarity: "legendary", blurb: "Nine blades, all swept the same way, wide where they meet the lip.", coins: 5100, cores: 68, look: { spokes: 9, spokeWidth: 0.04, spokeThick: 0.01, lip: 0.55, beadlock: false, color: "#e8eef5", metalness: 1, roughness: 0.1, turbine: true } },
  { id: "wh-split", slot: "wheel", name: "Split Dish", rarity: "rare", blurb: "A deep barrel and five spokes that fork before the lip.", coins: 1420, cores: 20, look: { spokes: 5, spokeWidth: 0.02, spokeThick: 0.012, lip: 1, beadlock: false, color: "#f2f5f8", metalness: 1, roughness: 0.07, turbine: false } },
  { id: "wh-mono", slot: "wheel", name: "Monoblock", rarity: "epic", blurb: "Five broad faces in a shallow cone. The slots are the only gaps.", coins: 2280, cores: 32, look: { spokes: 5, spokeWidth: 0.1, spokeThick: 0.012, lip: 0.35, beadlock: false, color: "#b7c0ca", metalness: 0.95, roughness: 0.16, turbine: false } },

  { id: "ti-hwy", slot: "tire", name: "Highway Rib", rarity: "common", blurb: "Quiet ribs for pavement and the long way home.", coins: 0, cores: 0, look: { radius: 0.38, width: 0.26, tread: "rib" } },
  { id: "ti-at", slot: "tire", name: "All-Terrain", rarity: "common", blurb: "A compromise tread that still knows what gravel is.", coins: 240, cores: 4, look: { radius: 0.4, width: 0.28, tread: "allterrain" } },
  { id: "ti-mud", slot: "tire", name: "Mud Claw", rarity: "rare", blurb: "Chunky lugs that throw dirt and don't apologize.", coins: 860, cores: 12, look: { radius: 0.43, width: 0.32, tread: "mud" } },
  { id: "ti-paddle", slot: "tire", name: "Paddle Cut", rarity: "epic", blurb: "Wide scoops for loose sand, noisy everywhere else.", coins: 2300, cores: 32, look: { radius: 0.45, width: 0.34, tread: "paddle" } },

  { id: "lf-0", slot: "lift", name: "Stock Height", rarity: "common", blurb: "Factory ride. The fenders still know the tires.", coins: 0, cores: 0, look: { inches: 0, amount: 0 } },
  { id: "lf-2", slot: "lift", name: "Trail 2\"", rarity: "common", blurb: "A modest spacer. Room for a thicker tire, not a parade.", coins: 360, cores: 6, look: { inches: 2, amount: 0.1 } },
  { id: "lf-4", slot: "lift", name: "Ridge 4\"", rarity: "rare", blurb: "Daylight under the rocker and a longer shock.", coins: 1100, cores: 16, look: { inches: 4, amount: 0.2 } },
  { id: "lf-6", slot: "lift", name: "Dune 6\"", rarity: "epic", blurb: "The body sits up like it heard a rumor about rocks.", coins: 2200, cores: 32, look: { inches: 6, amount: 0.32 } },

  { id: "bp-factory", slot: "bumper", name: "Factory Bar", rarity: "common", blurb: "Body-color and tidy. It matches because it never left.", coins: 0, cores: 0, look: { kind: "factory" } },
  { id: "bp-tube", slot: "bumper", name: "Tube Guard", rarity: "rare", blurb: "A black hoop with two uprights. Brush, not boulevard.", coins: 980, cores: 14, look: { kind: "tube" } },
  { id: "bp-winch", slot: "bumper", name: "Winch Plate", rarity: "epic", blurb: "A flat plate and a drum, for the day the wash wins.", coins: 2400, cores: 34, look: { kind: "winch" } },
  { id: "bp-pre", slot: "bumper", name: "Prerunner Hoop", rarity: "legendary", blurb: "Tubes pushed forward, with a skid plate underneath.", coins: 4900, cores: 68, look: { kind: "prerunner" } },

  { id: "lt-pods", slot: "light", name: "Fog Pods", rarity: "common", blurb: "Two warm pods on the valence. Enough for a trailhead.", coins: 0, cores: 0, look: { kind: "pods" } },
  { id: "lt-bar", slot: "light", name: "Roof Bar", rarity: "rare", blurb: "A single cool bar above the windshield.", coins: 900, cores: 14, look: { kind: "bar" } },
  { id: "lt-dual", slot: "light", name: "Horizon Dual", rarity: "epic", blurb: "Roof bar plus the pods. The desert gets no shadows.", coins: 2100, cores: 30, look: { kind: "dual" } },

  { id: "ex-stock", slot: "exhaust", name: "Tucked Pipe", rarity: "common", blurb: "One pipe, hidden until you crouch.", coins: 0, cores: 0, look: { kind: "stock" } },
  { id: "ex-side", slot: "exhaust", name: "Side Exit", rarity: "rare", blurb: "A thick tip ahead of the rear tire.", coins: 780, cores: 12, look: { kind: "side" } },
  { id: "ex-stack", slot: "exhaust", name: "Twin Stack", rarity: "legendary", blurb: "Two chrome stacks rising behind the cab.", coins: 4600, cores: 64, look: { kind: "stack" } },

  { id: "sp-none", slot: "spoiler", name: "Clean Tail", rarity: "common", blurb: "No wing. The tailgate is allowed to be a tailgate.", coins: 0, cores: 0, look: { kind: "none" } },
  { id: "sp-lip", slot: "spoiler", name: "Deck Lip", rarity: "rare", blurb: "A low lip on the tailgate. Mostly a drawing.", coins: 720, cores: 10, look: { kind: "lip" } },
  { id: "sp-wing", slot: "spoiler", name: "Span Wing", rarity: "epic", blurb: "Pedestals and a wide plane. It means the sport truck.", coins: 2000, cores: 28, look: { kind: "wing" } },

  { id: "wr-clean", slot: "wrap", name: "Bare", rarity: "common", blurb: "Paint only. Panel gaps do the talking.", coins: 0, cores: 0, look: { kind: "clean", accent: "#ffffff" } },
  { id: "wr-stripe", slot: "wrap", name: "Centerline", rarity: "common", blurb: "A beltline stripe and a hood spear in copper.", coins: 280, cores: 4, look: { kind: "stripe", accent: "#ff8a3d" } },
  { id: "wr-geo", slot: "wrap", name: "Breakline", rarity: "rare", blurb: "Broken chevrons along the doors.", coins: 1240, cores: 16, look: { kind: "geo", accent: "#f2c56e" } },
  { id: "wr-sunset", slot: "wrap", name: "Dusk Fade", rarity: "epic", blurb: "A warm fade that pools toward the rear quarter.", coins: 2700, cores: 36, look: { kind: "sunset", accent: "#ff7a3c" } },
  { id: "wr-circuit", slot: "wrap", name: "Myth Circuit", rarity: "legendary", blurb: "Thin luminous lines, like a map of a road that isn't real.", coins: 5600, cores: 74, look: { kind: "circuit", accent: "#3dffe0" } },
]

export const CATEGORIES: { id: "paint" | Slot; label: string }[] = [
  { id: "paint", label: "Paint" },
  { id: "wheel", label: "Wheels" },
  { id: "tire", label: "Tires" },
  { id: "lift", label: "Lift" },
  { id: "bumper", label: "Bumpers" },
  { id: "light", label: "Lights" },
  { id: "exhaust", label: "Exhaust" },
  { id: "spoiler", label: "Spoilers" },
  { id: "wrap", label: "Wraps" },
]

export const STARTER_LOADOUT: Loadout = {
  paint: "copper",
  finish: "gloss",
  wheel: "wh-five",
  tire: "ti-hwy",
  lift: "lf-0",
  bumper: "bp-factory",
  light: "lt-pods",
  exhaust: "ex-stock",
  spoiler: "sp-none",
  wrap: "wr-clean",
}

const partMap = new Map(PARTS.map((part) => [part.id, part]))
const truckMap = new Map(TRUCKS.map((truck) => [truck.id, truck]))

export function partById(id: string): Part | undefined {
  return partMap.get(id)
}

export function truckById(id: string): TruckSpec | undefined {
  return truckMap.get(id)
}

export function partsFor(slot: Slot): Part[] {
  return PARTS.filter((part) => part.slot === slot)
}

export function paintById(id: string): Paint | undefined {
  return PAINTS.find((paint) => paint.id === id)
}

export function finishById(id: string): Finish | undefined {
  return FINISHES.find((finish) => finish.id === id)
}

export function starterLoadout(truck: TruckSpec): Loadout {
  return { ...STARTER_LOADOUT, paint: truck.paint }
}

export function rarityLabel(rarity: Rarity): string {
  if (rarity === "legendary") return "Legendary"
  return rarity.slice(0, 1).toUpperCase() + rarity.slice(1)
}

export function isFreePart(part: Part): boolean {
  return part.coins === 0 && part.cores === 0
}
