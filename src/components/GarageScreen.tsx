import { ChevronLeft, ChevronRight } from "lucide-react"
import { useState } from "react"
import {
  CATEGORIES,
  FINISHES,
  PAINTS,
  PARTS,
  RARITY_COLOR,
  TRUCKS,
  isFreePart,
  paintById,
  partsFor,
  rarityLabel,
  truckById,
} from "../content/catalog"
import type { CategoryId, Rarity } from "../content/types"
import { formatCount } from "../lib/format"
import { useGame } from "../game/store"
import { GarageScene } from "../three/GarageScene"
import { Button } from "./ui/button"

function hasWebGL() {
  try {
    const canvas = document.createElement("canvas")
    return Boolean(canvas.getContext("webgl2") || canvas.getContext("webgl"))
  } catch {
    return false
  }
}

export function GarageScreen({ active }: { active: boolean }) {
  const truckId = useGame((s) => s.truckId)
  const loadout = useGame((s) => s.loadouts[s.truckId])
  const owned = useGame((s) => s.owned)
  const coins = useGame((s) => s.coins)
  const cores = useGame((s) => s.cores)
  const seenIntro = useGame((s) => s.seenIntro)
  const selectTruck = useGame((s) => s.selectTruck)
  const setPaint = useGame((s) => s.setPaint)
  const setFinish = useGame((s) => s.setFinish)
  const equip = useGame((s) => s.equip)
  const buy = useGame((s) => s.buy)
  const dismissIntro = useGame((s) => s.dismissIntro)
  const setTab = useGame((s) => s.setTab)
  const [category, setCategory] = useState<CategoryId>("paint")
  const [webgl] = useState(hasWebGL)
  const truck = truckById(truckId) ?? TRUCKS[0]
  if (!truck || !loadout) return null
  const index = TRUCKS.findIndex((item) => item.id === truck.id)
  const equipped = loadout[category === "paint" ? "wheel" : category]
  return (
    <div className="flex h-full min-h-0 flex-col lg:grid lg:grid-cols-[minmax(0,1fr)_400px]">
      <div className="relative min-h-[240px] flex-1">
        {webgl ? (
          <GarageScene spec={truck} loadout={loadout} active={active} />
        ) : (
          <div className="grid h-full place-items-center p-6 text-center text-sm text-muted">
            This browser can't open the 3D bay. Parts and the trail still work.
          </div>
        )}
        <p className="pointer-events-none absolute bottom-3 left-4 text-xs text-cream/80">Drag to look · pinch to zoom</p>
        {seenIntro ? null : (
          <div className="absolute inset-x-4 bottom-10 rounded-3xl border border-white/10 bg-ink/90 p-4 shadow-xl">
            <p className="text-xs uppercase tracking-[0.16em] text-copper">Prototype bay</p>
            <p className="mt-1 text-sm text-cream">
              Fictional trucks, a trail that pays coins, and a test register. Nothing here charges a card.
            </p>
            <Button className="mt-3" onClick={dismissIntro}>
              Roll in
            </Button>
          </div>
        )}
      </div>
      <section className="flex min-h-0 flex-1 flex-col border-t border-white/10 bg-panel lg:border-t-0 lg:border-l">
        <div className="flex items-center justify-between gap-2 px-3 pt-3">
          <button type="button" aria-label="Previous truck" className="grid h-11 w-11 place-items-center rounded-full bg-panel-2" onClick={() => selectTruck(TRUCKS[(index + TRUCKS.length - 1) % TRUCKS.length]!.id)}>
            <ChevronLeft />
          </button>
          <div className="text-center">
            <p className="text-[11px] uppercase tracking-[0.18em] text-muted">{truck.brand}</p>
            <h1 className="font-display text-3xl leading-none">{truck.model}</h1>
            <p className="text-xs text-copper">{truck.role}</p>
          </div>
          <button type="button" aria-label="Next truck" className="grid h-11 w-11 place-items-center rounded-full bg-panel-2" onClick={() => selectTruck(TRUCKS[(index + 1) % TRUCKS.length]!.id)}>
            <ChevronRight />
          </button>
        </div>
        <p className="px-4 pt-2 text-sm text-muted">{truck.blurb}</p>
        <div className="no-scrollbar flex gap-2 overflow-x-auto px-3 py-3">
          {CATEGORIES.map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setCategory(item.id)}
              className={`shrink-0 rounded-full px-3 py-2 text-xs font-semibold ${category === item.id ? "bg-copper text-ink" : "bg-panel-2 text-cream"}`}
            >
              {item.label}
            </button>
          ))}
        </div>
        <div className="no-scrollbar flex min-h-0 flex-1 gap-3 overflow-x-auto px-3 pb-4">
          {category === "paint" ? (
            <div className="w-full">
              <div className="grid grid-cols-4 gap-2">
                {PAINTS.map((paint) => (
                  <button
                    key={paint.id}
                    type="button"
                    aria-label={paint.name}
                    aria-pressed={loadout.paint === paint.id}
                    onClick={() => setPaint(paint.id)}
                    className={`h-14 rounded-2xl border-2 ${loadout.paint === paint.id ? "border-copper" : "border-transparent"}`}
                    style={{ background: paint.hex }}
                  />
                ))}
              </div>
              <p className="mt-3 text-sm">{paintById(loadout.paint)?.name}</p>
              <div className="mt-2 flex flex-wrap gap-2">
                {FINISHES.map((finish) => (
                  <button
                    key={finish.id}
                    type="button"
                    aria-pressed={loadout.finish === finish.id}
                    onClick={() => setFinish(finish.id)}
                    className={`rounded-full px-3 py-2 text-xs font-semibold ${loadout.finish === finish.id ? "bg-cream text-ink" : "bg-panel-2"}`}
                  >
                    {finish.name}
                  </button>
                ))}
              </div>
            </div>
          ) : (
            partsFor(category).map((part) => {
              const have = owned.includes(part.id)
              const on = equipped === part.id
              return (
                <article
                  key={part.id}
                  className={`flex w-40 shrink-0 flex-col rounded-2xl border bg-panel-2 p-3 ${part.rarity === "legendary" ? "legend-sheen" : ""} ${on ? "border-copper" : "border-white/10"}`}
                >
                  <p className="text-[10px] uppercase tracking-[0.14em]" style={{ color: RARITY_COLOR[part.rarity as Rarity] }}>
                    {rarityLabel(part.rarity)}
                  </p>
                  <h2 className="font-display text-2xl leading-none">{part.name}</h2>
                  <p className="mt-1 line-clamp-3 flex-1 text-xs text-muted">{part.blurb}</p>
                  {have ? (
                    <Button size="sm" variant={on ? "secondary" : "default"} className="mt-3" onClick={() => equip(part.id)}>
                      {on ? "Equipped" : "Equip"}
                    </Button>
                  ) : (
                    <div className="mt-3 grid gap-2">
                      <Button size="sm" disabled={!isFreePart(part) && coins < part.coins} onClick={() => buy(part.id, "coins")}>
                        {formatCount(part.coins)} coins
                      </Button>
                      <Button size="sm" variant="secondary" disabled={cores < part.cores} onClick={() => buy(part.id, "cores")}>
                        {part.cores} Cores
                      </Button>
                      {cores < part.cores ? (
                        <button type="button" className="text-xs text-copper" onClick={() => setTab("store")}>
                          Get Cores
                        </button>
                      ) : null}
                    </div>
                  )}
                </article>
              )
            })
          )}
        </div>
        <p className="px-4 pb-3 text-xs text-muted">
          {owned.length} of {PARTS.length} parts in the bay
        </p>
      </section>
    </div>
  )
}
