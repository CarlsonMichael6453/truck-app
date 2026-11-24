import type { Product } from "./types"

/**
 * Fixed kits and Core packs. Every part id here also has a coin price in the
 * catalog, so the same items can be earned. There is no random draw.
 */
export const PRODUCTS: Product[] = [
  {
    id: "cores_small",
    title: "Core pouch",
    detail: "80 Cores. Spend them on any part in the garage.",
    priceLabel: "$0.99",
    kind: "consumable",
    grants: { cores: 80 },
  },
  {
    id: "cores_medium",
    title: "Core crate",
    detail: "200 Cores. A shortcut, not a different catalog.",
    priceLabel: "$1.99",
    kind: "consumable",
    grants: { cores: 200 },
  },
  {
    id: "cores_large",
    title: "Core vault",
    detail: "550 Cores. Still the same parts the trail pays for.",
    priceLabel: "$4.99",
    kind: "consumable",
    grants: { cores: 550 },
  },
  {
    id: "bundle_trail",
    title: "Trail kit",
    detail: "Deep Lip wheels, Mud Claw tires, and the Ridge 4\" lift.",
    priceLabel: "$2.99",
    kind: "nonconsumable",
    grants: { partIds: ["wh-deep", "ti-mud", "lf-4"] },
  },
  {
    id: "bundle_night",
    title: "Night shift kit",
    detail: "Horizon Dual lights, Side Exit exhaust, and the Breakline wrap.",
    priceLabel: "$3.99",
    kind: "nonconsumable",
    grants: { partIds: ["lt-dual", "ex-side", "wr-geo"] },
  },
  {
    id: "bundle_show",
    title: "Showfield kit",
    detail: "Solar Turbine wheels, Twin Stacks, the Prerunner Hoop, and Myth Circuit.",
    priceLabel: "$6.99",
    kind: "nonconsumable",
    grants: { partIds: ["wh-turbine", "ex-stack", "bp-pre", "wr-circuit"] },
  },
]

const productMap = new Map(PRODUCTS.map((product) => [product.id, product]))

export function productById(id: string): Product | undefined {
  return productMap.get(id)
}
