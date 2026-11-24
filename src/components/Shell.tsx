import { Flag, ShoppingBag, Truck } from "lucide-react"
import { useEffect } from "react"
import { formatCount } from "../lib/format"
import { useGame, type Tab } from "../game/store"
import { GarageScreen } from "./GarageScreen"
import { PlayScreen } from "./PlayScreen"
import { StoreScreen } from "./StoreScreen"

const TABS: { id: Tab; label: string; icon: typeof Truck }[] = [
  { id: "garage", label: "Garage", icon: Truck },
  { id: "play", label: "Play", icon: Flag },
  { id: "store", label: "Store", icon: ShoppingBag },
]

export function Shell() {
  const tab = useGame((s) => s.tab)
  const setTab = useGame((s) => s.setTab)
  const runActive = useGame((s) => s.runActive)
  const coins = useGame((s) => s.coins)
  const cores = useGame((s) => s.cores)
  const toasts = useGame((s) => s.toasts)
  const dismissToast = useGame((s) => s.dismissToast)
  useEffect(() => {
    if (!toasts.length) return
    const timers = toasts.map((toast) => window.setTimeout(() => dismissToast(toast.id), 3400))
    return () => {
      for (const timer of timers) window.clearTimeout(timer)
    }
  }, [toasts, dismissToast])
  return (
    <div className="flex h-dvh flex-col bg-ink text-cream">
      {runActive ? null : (
        <header className="flex shrink-0 items-center justify-between gap-3 px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-2">
          <div>
            <p className="font-display text-2xl leading-none tracking-wide">TRUCK APP</p>
            <p className="text-[11px] uppercase tracking-[0.18em] text-muted">Omnipresent Games</p>
          </div>
          <div className="flex items-center gap-2 text-sm">
            <span className="rounded-full bg-panel px-3 py-1 font-semibold text-copper">{formatCount(coins)}</span>
            <span className="rounded-full bg-panel px-3 py-1 font-semibold text-copper-2">{formatCount(cores)} Cores</span>
          </div>
        </header>
      )}
      <main className="min-h-0 flex-1">
        <div className={tab === "garage" ? "h-full" : "hidden"} aria-hidden={tab !== "garage"}>
          <GarageScreen active={tab === "garage"} />
        </div>
        {tab === "play" ? <PlayScreen /> : null}
        {tab === "store" ? <StoreScreen /> : null}
      </main>
      <nav className="grid shrink-0 grid-cols-3 border-t border-white/10 bg-ink/95 pb-[env(safe-area-inset-bottom)]">
        {TABS.map((item) => {
          const Icon = item.icon
          const current = tab === item.id
          return (
            <button
              key={item.id}
              type="button"
              aria-current={current ? "page" : undefined}
              className={`flex min-h-16 flex-col items-center justify-center gap-1 text-xs ${current ? "text-copper" : "text-muted"}`}
              onClick={() => setTab(item.id)}
            >
              <Icon size={20} />
              {item.label}
            </button>
          )
        })}
      </nav>
      <div className="pointer-events-none fixed inset-x-0 top-[max(0.75rem,env(safe-area-inset-top))] z-40 flex flex-col items-center gap-2">
        {toasts.map((toast) => (
          <button
            key={toast.id}
            type="button"
            className="pointer-events-auto max-w-sm rounded-full bg-cream px-4 py-2 text-sm font-medium text-ink shadow-lg"
            onClick={() => dismissToast(toast.id)}
          >
            {toast.text}
          </button>
        ))}
      </div>
    </div>
  )
}
