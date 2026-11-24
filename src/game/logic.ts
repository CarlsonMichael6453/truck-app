import {
  FINISHES,
  PAINTS,
  PARTS,
  TRUCKS,
  isFreePart,
  paintById,
  partById,
  starterLoadout,
  truckById,
} from "../content/catalog"
import { productById } from "../content/products"
import { DAILY_REWARDS, QUESTS } from "../content/quests"
import type { Loadout, Part, Quest, QuestMetric } from "../content/types"
import type { RunPayout } from "./runner"

export const SAVE_KEY = "omnipresent.truck-app.v1"

export type Receipt = {
  id: string
  productId: string
  at: string
  mode: "mock"
}

export type Stats = {
  runs: number
  finishes: number
  cleanFinishes: number
  bestDistance: number
  bestCoins: number
  gulchFinishes: number
  partsBought: number
  dailiesClaimed: number
  streak: number
  lastDaily: string | null
  purchasedProductIds: string[]
  receipts: Receipt[]
}

export type Persisted = {
  version: 1
  coins: number
  cores: number
  owned: string[]
  truckId: string
  loadouts: Record<string, Loadout>
  stats: Stats
  questRewarded: string[]
  seenIntro: boolean
  sound: boolean
}

export type ActionResult = {
  state: Persisted
  toasts: string[]
  error?: string
}

export function emptyStats(): Stats {
  return {
    runs: 0,
    finishes: 0,
    cleanFinishes: 0,
    bestDistance: 0,
    bestCoins: 0,
    gulchFinishes: 0,
    partsBought: 0,
    dailiesClaimed: 0,
    streak: 0,
    lastDaily: null,
    purchasedProductIds: [],
    receipts: [],
  }
}

export function defaultPersisted(): Persisted {
  const loadouts: Record<string, Loadout> = {}
  for (const truck of TRUCKS) loadouts[truck.id] = starterLoadout(truck)
  return {
    version: 1,
    coins: 750,
    cores: 0,
    owned: PARTS.filter(isFreePart).map((part) => part.id),
    truckId: TRUCKS[0]?.id ?? "ridgehaul-summit",
    loadouts,
    stats: emptyStats(),
    questRewarded: [],
    seenIntro: false,
    sound: false,
  }
}

export function localDayKey(date = new Date()): string {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, "0")
  const d = String(date.getDate()).padStart(2, "0")
  return `${y}-${m}-${d}`
}

export function previousDayKey(key: string): string {
  const [y, m, d] = key.split("-").map(Number)
  const date = new Date(y || 1970, (m || 1) - 1, d || 1)
  date.setDate(date.getDate() - 1)
  return localDayKey(date)
}

export function normalize(raw: unknown): Persisted {
  const base = defaultPersisted()
  if (!raw || typeof raw !== "object") return base
  const data = raw as Partial<Persisted>
  const owned = new Set(base.owned)
  if (Array.isArray(data.owned)) {
    for (const id of data.owned) {
      if (typeof id === "string" && partById(id)) owned.add(id)
    }
  }
  const truckId = typeof data.truckId === "string" && truckById(data.truckId) ? data.truckId : base.truckId
  const loadouts: Record<string, Loadout> = { ...base.loadouts }
  const rawLoadouts = data.loadouts
  if (rawLoadouts && typeof rawLoadouts === "object") {
    for (const truck of TRUCKS) {
      const candidate = rawLoadouts[truck.id]
      loadouts[truck.id] = sanitizeLoadout(candidate, owned, starterLoadout(truck))
    }
  }
  return {
    version: 1,
    coins: clampCount(data.coins, base.coins),
    cores: clampCount(data.cores, base.cores),
    owned: [...owned],
    truckId,
    loadouts,
    stats: sanitizeStats(data.stats),
    questRewarded: Array.isArray(data.questRewarded)
      ? data.questRewarded.filter((id): id is string => typeof id === "string" && QUESTS.some((quest) => quest.id === id))
      : [],
    seenIntro: data.seenIntro === true,
    sound: data.sound === true,
  }
}

function sanitizeLoadout(candidate: unknown, owned: Set<string>, fallback: Loadout): Loadout {
  const source = candidate && typeof candidate === "object" ? (candidate as Partial<Loadout>) : {}
  const paint = typeof source.paint === "string" && paintById(source.paint) ? source.paint : fallback.paint
  const finish = typeof source.finish === "string" && FINISHES.some((item) => item.id === source.finish) ? source.finish : fallback.finish
  return {
    paint,
    finish,
    wheel: ownedSlot(source.wheel, "wheel", owned, fallback.wheel),
    tire: ownedSlot(source.tire, "tire", owned, fallback.tire),
    lift: ownedSlot(source.lift, "lift", owned, fallback.lift),
    bumper: ownedSlot(source.bumper, "bumper", owned, fallback.bumper),
    light: ownedSlot(source.light, "light", owned, fallback.light),
    exhaust: ownedSlot(source.exhaust, "exhaust", owned, fallback.exhaust),
    spoiler: ownedSlot(source.spoiler, "spoiler", owned, fallback.spoiler),
    wrap: ownedSlot(source.wrap, "wrap", owned, fallback.wrap),
  }
}

function ownedSlot(id: unknown, slot: Part["slot"], owned: Set<string>, fallback: string): string {
  if (typeof id !== "string") return fallback
  const part = partById(id)
  if (!part || part.slot !== slot || !owned.has(id)) return fallback
  return id
}

function sanitizeStats(value: unknown): Stats {
  const base = emptyStats()
  if (!value || typeof value !== "object") return base
  const stats = value as Partial<Stats>
  const receipts = Array.isArray(stats.receipts)
    ? stats.receipts.flatMap((receipt) => {
        if (!receipt || typeof receipt !== "object") return []
        const item = receipt as Partial<Receipt>
        if (typeof item.id !== "string" || typeof item.productId !== "string" || typeof item.at !== "string") return []
        if (!productById(item.productId)) return []
        return [{ id: item.id, productId: item.productId, at: item.at, mode: "mock" as const }]
      }).slice(-40)
    : []
  const purchased = Array.isArray(stats.purchasedProductIds)
    ? stats.purchasedProductIds.filter((id): id is string => typeof id === "string" && Boolean(productById(id)))
    : []
  return {
    runs: clampCount(stats.runs, 0),
    finishes: clampCount(stats.finishes, 0),
    cleanFinishes: clampCount(stats.cleanFinishes, 0),
    bestDistance: clampCount(stats.bestDistance, 0),
    bestCoins: clampCount(stats.bestCoins, 0),
    gulchFinishes: clampCount(stats.gulchFinishes, 0),
    partsBought: clampCount(stats.partsBought, 0),
    dailiesClaimed: clampCount(stats.dailiesClaimed, 0),
    streak: clampCount(stats.streak, 0),
    lastDaily: typeof stats.lastDaily === "string" && /^\d{4}-\d{2}-\d{2}$/.test(stats.lastDaily) ? stats.lastDaily : null,
    purchasedProductIds: purchased,
    receipts,
  }
}

function clampCount(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback
  return Math.max(0, Math.min(1_000_000, Math.floor(value)))
}

export function metricValue(state: Persisted, metric: QuestMetric): number {
  switch (metric) {
    case "runs":
      return state.stats.runs
    case "clean":
      return state.stats.cleanFinishes
    case "bestCoins":
      return state.stats.bestCoins
    case "bestDistance":
      return state.stats.bestDistance
    case "gulch":
      return state.stats.gulchFinishes
    case "parts":
      return state.stats.partsBought
    case "dailies":
      return state.stats.dailiesClaimed
  }
}

export function grantReadyQuests(state: Persisted): { state: Persisted; toasts: string[] } {
  let next = state
  const toasts: string[] = []
  for (const quest of QUESTS) {
    if (next.questRewarded.includes(quest.id)) continue
    if (metricValue(next, quest.metric) < quest.goal) continue
    const applied = applyQuestReward(next, quest)
    next = applied.state
    toasts.push(...applied.toasts)
  }
  return { state: next, toasts }
}

function applyQuestReward(state: Persisted, quest: Quest): { state: Persisted; toasts: string[] } {
  let next: Persisted = { ...state, questRewarded: [...state.questRewarded, quest.id], owned: [...state.owned] }
  const toasts: string[] = []
  if (quest.rewardCoins) {
    next = { ...next, coins: next.coins + quest.rewardCoins }
    toasts.push(`${quest.title}: +${quest.rewardCoins} coins.`)
  }
  if (quest.rewardPartId) {
    const part = partById(quest.rewardPartId)
    if (part && !next.owned.includes(part.id)) {
      next = { ...next, owned: [...next.owned, part.id] }
      toasts.push(`${part.name} unlocked. It's in the garage.`)
    } else {
      const coins = quest.duplicateCoins ?? 0
      next = { ...next, coins: next.coins + coins }
      toasts.push(`${quest.title}: you already had that part. +${coins} coins.`)
    }
  }
  return { state: next, toasts }
}

function withQuests(state: Persisted, toasts: string[]): ActionResult {
  const quests = grantReadyQuests(state)
  return { state: quests.state, toasts: [...toasts, ...quests.toasts] }
}

function fail(state: Persisted, error: string): ActionResult {
  return { state, toasts: [], error }
}

export function selectTruck(state: Persisted, truckId: string): ActionResult {
  if (!truckById(truckId)) return fail(state, "That truck isn't in the bay.")
  return { state: { ...state, truckId }, toasts: [] }
}

export function setPaint(state: Persisted, paintId: string): ActionResult {
  if (!PAINTS.some((paint) => paint.id === paintId)) return fail(state, "Unknown paint.")
  return { state: updateLoadout(state, { paint: paintId }), toasts: [] }
}

export function setFinish(state: Persisted, finishId: string): ActionResult {
  if (!FINISHES.some((finish) => finish.id === finishId)) return fail(state, "Unknown finish.")
  return { state: updateLoadout(state, { finish: finishId }), toasts: [] }
}

export function equipPart(state: Persisted, partId: string): ActionResult {
  const part = partById(partId)
  if (!part) return fail(state, "Unknown part.")
  if (!state.owned.includes(partId)) return fail(state, "You don't own that yet.")
  return { state: updateLoadout(state, { [part.slot]: part.id }), toasts: [] }
}

export function buyPart(state: Persisted, partId: string, currency: "coins" | "cores"): ActionResult {
  const part = partById(partId)
  if (!part) return fail(state, "Unknown part.")
  if (state.owned.includes(partId)) return fail(state, "Already in the garage.")
  const price = currency === "coins" ? part.coins : part.cores
  const balance = currency === "coins" ? state.coins : state.cores
  if (price <= 0) return fail(state, "That part is already included.")
  if (balance < price) {
    return fail(state, currency === "coins" ? "Not enough coins yet." : "Not enough Cores.")
  }
  const next: Persisted = {
    ...state,
    coins: currency === "coins" ? state.coins - price : state.coins,
    cores: currency === "cores" ? state.cores - price : state.cores,
    owned: [...state.owned, part.id],
    stats: { ...state.stats, partsBought: state.stats.partsBought + 1 },
  }
  return withQuests(updateLoadout(next, { [part.slot]: part.id }), [`${part.name} equipped.`])
}

function updateLoadout(state: Persisted, patch: Partial<Loadout>): Persisted {
  const current = state.loadouts[state.truckId] ?? starterLoadout(truckById(state.truckId) ?? TRUCKS[0]!)
  return {
    ...state,
    loadouts: {
      ...state.loadouts,
      [state.truckId]: { ...current, ...patch },
    },
  }
}

export function claimDaily(state: Persisted, today: string): ActionResult {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(today)) return fail(state, "Bad date.")
  if (state.stats.lastDaily === today) return fail(state, "Already claimed today.")
  const streak = state.stats.lastDaily === previousDayKey(today) ? state.stats.streak + 1 : 1
  const reward = DAILY_REWARDS[(streak - 1) % DAILY_REWARDS.length]
  if (!reward) return fail(state, "No reward is set.")
  let next: Persisted = {
    ...state,
    owned: [...state.owned],
    stats: {
      ...state.stats,
      streak,
      lastDaily: today,
      dailiesClaimed: state.stats.dailiesClaimed + 1,
    },
  }
  const toasts: string[] = []
  if (reward.partId) {
    const part = partById(reward.partId)
    if (part && !next.owned.includes(part.id)) {
      next = { ...next, owned: [...next.owned, part.id] }
      toasts.push(`${part.name} is in the garage.`)
    } else {
      const coins = reward.duplicateCoins ?? 0
      next = { ...next, coins: next.coins + coins }
      toasts.push(`You already had that part. +${coins} coins instead.`)
    }
  }
  if (reward.coins) {
    next = { ...next, coins: next.coins + reward.coins }
    toasts.push(`Daily bay: +${reward.coins} coins.`)
  }
  return withQuests(next, toasts)
}

export function applyRun(state: Persisted, payout: RunPayout, options?: { announce?: boolean }): ActionResult {
  const counted = payout.finished || payout.distance >= 40
  const next: Persisted = {
    ...state,
    coins: state.coins + Math.max(0, payout.coins),
    stats: {
      ...state.stats,
      runs: state.stats.runs + (counted ? 1 : 0),
      finishes: state.stats.finishes + (payout.finished ? 1 : 0),
      cleanFinishes: state.stats.cleanFinishes + (payout.clean ? 1 : 0),
      gulchFinishes: state.stats.gulchFinishes + (payout.finished && payout.trackId === "gulch" ? 1 : 0),
      bestDistance: Math.max(state.stats.bestDistance, payout.distance),
      bestCoins: Math.max(state.stats.bestCoins, payout.coins),
    },
  }
  const toasts = options?.announce ? [`Banked ${payout.coins} coins from the trail.`] : []
  return withQuests(next, toasts)
}

export function grantProduct(
  state: Persisted,
  productId: string,
  transactionId: string,
  at: string,
): ActionResult {
  const product = productById(productId)
  if (!product) return fail(state, "Unknown product.")
  if (state.stats.receipts.some((receipt) => receipt.id === transactionId)) {
    return fail(state, "That receipt was already applied.")
  }
  if (product.kind === "nonconsumable" && state.stats.purchasedProductIds.includes(product.id)) {
    return fail(state, "You already own this kit.")
  }
  let next: Persisted = {
    ...state,
    cores: state.cores + (product.grants.cores ?? 0),
    coins: state.coins + (product.grants.coins ?? 0),
    owned: [...state.owned],
    stats: {
      ...state.stats,
      purchasedProductIds:
        product.kind === "nonconsumable"
          ? [...state.stats.purchasedProductIds, product.id]
          : state.stats.purchasedProductIds,
      receipts: [
        ...state.stats.receipts,
        { id: transactionId, productId: product.id, at, mode: "mock" as const },
      ].slice(-40),
    },
  }
  const names: string[] = []
  for (const id of product.grants.partIds ?? []) {
    const part = partById(id)
    if (!part || next.owned.includes(id)) continue
    next = { ...next, owned: [...next.owned, id] }
    names.push(part.name)
  }
  const toasts: string[] = []
  if (product.grants.cores) toasts.push(`${product.grants.cores} Cores added. No charge was made.`)
  if (product.grants.coins) toasts.push(`${product.grants.coins} coins added. No charge was made.`)
  if (names.length) toasts.push(`${names.join(", ")} landed in the garage.`)
  if (!toasts.length) toasts.push("Nothing new to add. No charge was made.")
  return withQuests(next, toasts)
}

export function restorePurchases(state: Persisted): ActionResult {
  let next = state
  const gained: string[] = []
  for (const receipt of state.stats.receipts) {
    const product = productById(receipt.productId)
    if (!product || product.kind !== "nonconsumable") continue
    for (const id of product.grants.partIds ?? []) {
      const part = partById(id)
      if (!part || next.owned.includes(id)) continue
      next = { ...next, owned: [...next.owned, id] }
      gained.push(part.name)
    }
    if (!next.stats.purchasedProductIds.includes(product.id)) {
      next = {
        ...next,
        stats: { ...next.stats, purchasedProductIds: [...next.stats.purchasedProductIds, product.id] },
      }
    }
  }
  const toasts = gained.length ? [`Restored ${gained.join(", ")}.`] : ["Nothing to restore."]
  return { state: next, toasts }
}

export function freshPartIds(owned: string[], ids: string[] | undefined): string[] {
  return (ids ?? []).filter((id) => partById(id) && !owned.includes(id))
}

export function questViews(state: Persisted) {
  return QUESTS.map((quest) => {
    const raw = metricValue(state, quest.metric)
    return {
      ...quest,
      raw,
      value: Math.min(raw, quest.goal),
      done: state.questRewarded.includes(quest.id),
    }
  })
}

export function previewStreak(state: Persisted, today: string): number {
  if (state.stats.lastDaily === today) return state.stats.streak
  if (state.stats.lastDaily && state.stats.lastDaily === previousDayKey(today)) return state.stats.streak + 1
  return 1
}
