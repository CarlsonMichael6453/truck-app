import { useState } from "react"
import { partById } from "../content/catalog"
import { PRODUCTS } from "../content/products"
import type { Product } from "../content/types"
import { freshPartIds } from "../game/logic"
import type { PaymentOutcome } from "../game/payments"
import { useGame } from "../game/store"
import { formatCount } from "../lib/format"
import { Button } from "./ui/button"
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "./ui/dialog"

export function StoreScreen() {
  const coins = useGame((s) => s.coins)
  const cores = useGame((s) => s.cores)
  const owned = useGame((s) => s.owned)
  const purchased = useGame((s) => s.stats.purchasedProductIds)
  const purchase = useGame((s) => s.purchase)
  const restore = useGame((s) => s.restore)
  const reset = useGame((s) => s.reset)
  const [product, setProduct] = useState<Product | null>(null)
  const [phase, setPhase] = useState<"confirm" | "pending" | "done" | "error">("confirm")
  const [message, setMessage] = useState("")

  const run = async (outcome: PaymentOutcome) => {
    if (!product) return
    setPhase("pending")
    const result = await purchase(product.id, outcome)
    setMessage(result.message)
    setPhase(result.ok ? "done" : "error")
  }

  return (
    <div className="mx-auto h-full max-w-xl overflow-auto px-4 py-4">
      <div className="rounded-3xl border border-copper/40 bg-copper/10 p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-copper">Test mode</p>
        <p className="mt-1 text-sm">
          Confirming a purchase does not charge a card and does not contact Apple or Google. These are fixed lists of parts. There are no paid loot boxes.
        </p>
      </div>
      <p className="mt-4 text-sm text-muted">
        {formatCount(coins)} coins in the garage · {formatCount(cores)} Cores. Every part below can also be bought with coins you earn on the trail.
      </p>
      <h2 className="mt-6 font-display text-3xl">Kits</h2>
      <div className="mt-3 grid gap-3">
        {PRODUCTS.filter((item) => item.kind === "nonconsumable").map((item) => {
          const fresh = freshPartIds(owned, item.grants.partIds)
          const have = purchased.includes(item.id) || fresh.length === 0
          return (
            <article key={item.id} className="rounded-3xl border border-white/10 bg-panel p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="font-display text-2xl leading-none">{item.title}</h3>
                  <p className="mt-1 text-sm text-muted">{item.detail}</p>
                  <ul className="mt-2 text-sm">
                    {(item.grants.partIds ?? []).map((id) => (
                      <li key={id}>{partById(id)?.name}{owned.includes(id) ? " · owned" : ""}</li>
                    ))}
                  </ul>
                </div>
                <Button disabled={have} onClick={() => { setProduct(item); setPhase("confirm"); setMessage("") }}>
                  {have ? "In the garage" : item.priceLabel}
                </Button>
              </div>
            </article>
          )
        })}
      </div>
      <h2 className="mt-6 font-display text-3xl">Cores</h2>
      <div className="mt-3 grid gap-3">
        {PRODUCTS.filter((item) => item.kind === "consumable").map((item) => (
          <article key={item.id} className="flex items-center justify-between gap-3 rounded-3xl border border-white/10 bg-panel p-4">
            <div>
              <h3 className="font-display text-2xl leading-none">{item.title}</h3>
              <p className="text-sm text-muted">{item.detail}</p>
            </div>
            <Button onClick={() => { setProduct(item); setPhase("confirm"); setMessage("") }}>{item.priceLabel}</Button>
          </article>
        ))}
      </div>
      <div className="mt-6 flex flex-wrap gap-3 pb-8">
        <Button variant="secondary" onClick={() => void restore()}>Restore test purchases</Button>
        <Button variant="ghost" onClick={reset}>Reset this device</Button>
      </div>
      <Dialog open={product !== null} onOpenChange={(open) => { if (!open && phase !== "pending") setProduct(null) }}>
        <DialogContent>
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-copper">Test purchase · no charge</p>
          <DialogTitle>{product?.title}</DialogTitle>
          <DialogDescription>
            {phase === "pending" ? "Talking to the test register…" : phase === "done" ? message : phase === "error" ? message : `${product?.priceLabel}. ${product?.detail}`}
          </DialogDescription>
          {phase === "confirm" ? (
            <div className="mt-4 grid gap-2">
              <Button onClick={() => void run("success")}>Confirm test purchase</Button>
              <Button variant="secondary" onClick={() => setProduct(null)}>Cancel</Button>
              <button type="button" className="text-xs text-muted" onClick={() => void run("fail")}>Simulate a failed charge</button>
            </div>
          ) : phase === "pending" ? null : (
            <Button className="mt-4" onClick={() => setProduct(null)}>Close</Button>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}
