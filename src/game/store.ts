import { create } from "zustand"
import {
  SAVE_KEY,
  applyRun as applyRunLogic,
  buyPart,
  claimDaily as claimDailyLogic,
  defaultPersisted,
  equipPart,
  grantProduct,
  normalize,
  restorePurchases,
  selectTruck as selectTruckLogic,
  setFinish as setFinishLogic,
  setPaint as setPaintLogic,
  type ActionResult,
  type Persisted,
} from "./logic"
import { getPaymentProvider, type PaymentOutcome } from "./payments"
import type { RunPayout } from "./runner"

export type Tab = "garage" | "play" | "store"

export type Toast = { id: string; text: string }

type Store = Persisted & {
  tab: Tab
  toasts: Toast[]
  runActive: boolean
  setTab: (tab: Tab) => void
  setRunActive: (active: boolean) => void
  dismissIntro: () => void
  toggleSound: () => void
  selectTruck: (id: string) => void
  setPaint: (id: string) => void
  setFinish: (id: string) => void
  equip: (id: string) => void
  buy: (id: string, currency: "coins" | "cores") => void
  claimDaily: () => string[]
  applyRun: (payout: RunPayout, announce?: boolean) => string[]
  purchase: (productId: string, outcome?: PaymentOutcome) => Promise<{ ok: boolean; message: string }>
  restore: () => Promise<void>
  reset: () => void
  dismissToast: (id: string) => void
}

let toastN = 0

function makeToast(text: string): Toast {
  toastN += 1
  return { id: `${Date.now()}-${toastN}`, text }
}

function readSave(): Persisted {
  try {
    if (typeof localStorage === "undefined") return defaultPersisted()
    const raw = localStorage.getItem(SAVE_KEY)
    if (!raw) return defaultPersisted()
    return normalize(JSON.parse(raw) as unknown)
  } catch {
    return defaultPersisted()
  }
}

function writeSave(state: Persisted) {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(state))
  } catch {
    // Private mode can refuse storage. The session still works.
  }
}

function snapshot(state: Store): Persisted {
  return {
    version: 1,
    coins: state.coins,
    cores: state.cores,
    owned: state.owned,
    truckId: state.truckId,
    loadouts: state.loadouts,
    stats: state.stats,
    questRewarded: state.questRewarded,
    seenIntro: state.seenIntro,
    sound: state.sound,
  }
}

export const useGame = create<Store>((set, get) => {
  const commit = (result: ActionResult, keepToasts: boolean) => {
    const texts = result.error ? [result.error] : keepToasts ? result.toasts : []
    const toasts = [...get().toasts, ...texts.filter(Boolean).map(makeToast)].slice(-3)
    if (result.error) {
      set({ toasts })
      return
    }
    set({ ...result.state, toasts })
    writeSave(result.state)
  }

  return {
    ...readSave(),
    tab: "garage",
    toasts: [],
    runActive: false,
    setTab: (tab) => set({ tab }),
    setRunActive: (runActive) => set({ runActive }),
    dismissIntro: () => {
      const next = { ...snapshot(get()), seenIntro: true }
      set(next)
      writeSave(next)
    },
    toggleSound: () => {
      const next = { ...snapshot(get()), sound: !get().sound }
      set(next)
      writeSave(next)
    },
    selectTruck: (id) => commit(selectTruckLogic(snapshot(get()), id), false),
    setPaint: (id) => commit(setPaintLogic(snapshot(get()), id), false),
    setFinish: (id) => commit(setFinishLogic(snapshot(get()), id), false),
    equip: (id) => commit(equipPart(snapshot(get()), id), false),
    buy: (id, currency) => commit(buyPart(snapshot(get()), id, currency), true),
    claimDaily: () => {
      const dated = claimDailyLogic(snapshot(get()), localToday())
      commit(dated, true)
      return dated.error ? [dated.error] : dated.toasts
    },
    applyRun: (payout, announce = false) => {
      const result = applyRunLogic(snapshot(get()), payout, { announce })
      commit({ ...result, toasts: announce ? result.toasts : [] }, true)
      return result.toasts
    },
    purchase: async (productId, outcome = "success") => {
      try {
        const payment = await getPaymentProvider().purchase(productId, { outcome })
        if (!payment.ok) return { ok: false, message: payment.message }
        const granted = grantProduct(snapshot(get()), payment.productId, payment.transactionId, new Date().toISOString())
        commit(granted, true)
        if (granted.error) return { ok: false, message: granted.error }
        return { ok: true, message: granted.toasts[0] ?? "Added. No charge was made." }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Payments are unavailable."
        set({ toasts: [...get().toasts, makeToast(message)].slice(-3) })
        return { ok: false, message }
      }
    },
    restore: async () => {
      await getPaymentProvider().restore()
      commit(restorePurchases(snapshot(get())), true)
    },
    reset: () => {
      const fresh = defaultPersisted()
      set({ ...fresh, tab: get().tab, runActive: false, toasts: [makeToast("Garage reset on this device.")] })
      writeSave(fresh)
    },
    dismissToast: (id) => set({ toasts: get().toasts.filter((toast) => toast.id !== id) }),
  }
})

function localToday() {
  const date = new Date()
  const month = String(date.getMonth() + 1).padStart(2, "0")
  const day = String(date.getDate()).padStart(2, "0")
  return `${date.getFullYear()}-${month}-${day}`
}
