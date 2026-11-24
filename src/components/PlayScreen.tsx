import { useEffect, useRef, useState, type PointerEvent } from "react"
import { paintById, partById } from "../content/catalog"
import { DAILY_REWARDS } from "../content/quests"
import { TRACKS } from "../content/tracks"
import type { Loadout } from "../content/types"
import { drawRun, type Dust, type RunLook } from "../game/drawRun"
import { previewStreak, questViews } from "../game/logic"
import { bailRun, createRun, previewCoins, settleRun, stepRun, type RunPayout, type RunState } from "../game/runner"
import { playTone } from "../game/sfx"
import { useGame } from "../game/store"
import { formatCount } from "../lib/format"
import { Button } from "./ui/button"

function lookOf(loadout: Loadout | undefined): RunLook {
  const paint = paintById(loadout?.paint ?? "copper")?.hex ?? "#c4622d"
  const tire = partById(loadout?.tire ?? "ti-hwy")
  const lift = partById(loadout?.lift ?? "lf-0")
  const light = partById(loadout?.light ?? "lt-pods")
  const spoiler = partById(loadout?.spoiler ?? "sp-none")
  const wrap = partById(loadout?.wrap ?? "wr-clean")
  return {
    paint,
    accent: wrap?.slot === "wrap" ? wrap.look.accent : "#ff8a3d",
    lift: lift?.slot === "lift" ? lift.look.amount : 0,
    tireScale: tire?.slot === "tire" ? tire.look.radius / 0.38 : 1,
    light: light?.slot === "light" ? light.look.kind : "pods",
    spoiler: spoiler?.slot === "spoiler" ? spoiler.look.kind : "none",
    stripe: wrap?.slot === "wrap" && wrap.look.kind !== "clean",
  }
}

export function PlayScreen() {
  const [trackId, setTrackId] = useState(TRACKS[0]!.id)
  const [phase, setPhase] = useState<"lobby" | "run" | "result">("lobby")
  const [summary, setSummary] = useState<RunPayout | null>(null)
  const [notes, setNotes] = useState<string[]>([])
  const track = TRACKS.find((item) => item.id === trackId) ?? TRACKS[0]!
  if (phase === "run") {
    return (
      <RunView
        track={track}
        onDone={(payout, questNotes) => {
          setSummary(payout)
          setNotes(questNotes)
          setPhase("result")
        }}
      />
    )
  }
  if (phase === "result" && summary) {
    return (
      <div className="mx-auto flex h-full max-w-xl flex-col justify-center gap-4 p-5">
        <p className="text-xs uppercase tracking-[0.16em] text-copper">{track.name}</p>
        <h1 className="font-display text-5xl leading-none">
          {summary.clean ? "Clean line" : summary.finished ? "You made the end" : summary.status === "bailed" ? "You pulled off" : "The wash got you"}
        </h1>
        <dl className="grid grid-cols-3 gap-2 text-center">
          <Stat label="Meters" value={formatCount(summary.distance)} />
          <Stat label="Hits" value={String(summary.hits)} />
          <Stat label="Coins" value={formatCount(summary.coins)} />
        </dl>
        {notes.length ? <ul className="space-y-1 text-sm text-muted">{notes.map((note) => <li key={note}>{note}</li>)}</ul> : null}
        <Button onClick={() => setPhase("run")}>Ride again</Button>
        <Button variant="secondary" onClick={() => setPhase("lobby")}>Trail board</Button>
      </div>
    )
  }
  return <Lobby trackId={trackId} onTrack={setTrackId} onStart={() => setPhase("run")} />
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-panel p-3">
      <dt className="text-[11px] uppercase tracking-wider text-muted">{label}</dt>
      <dd className="font-display text-3xl">{value}</dd>
    </div>
  )
}

function Lobby({ trackId, onTrack, onStart }: { trackId: string; onTrack: (id: string) => void; onStart: () => void }) {
  const state = useGame()
  const today = localDay()
  const streak = previewStreak(state, today)
  const reward = DAILY_REWARDS[(Math.max(1, streak) - 1) % DAILY_REWARDS.length]
  const claimed = state.stats.lastDaily === today
  const quests = questViews(state)
  return (
    <div className="mx-auto h-full max-w-xl overflow-auto px-4 py-4">
      <div className="rounded-3xl border border-white/10 bg-panel p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-xs uppercase tracking-[0.16em] text-copper">Daily bay</p>
            <h2 className="font-display text-3xl leading-none">{reward?.label}</h2>
            <p className="mt-1 text-sm text-muted">Streak {claimed ? state.stats.streak : streak}. Come back tomorrow to keep it.</p>
          </div>
          <Button disabled={claimed} onClick={() => state.claimDaily()}>
            {claimed ? "Claimed" : "Claim"}
          </Button>
        </div>
      </div>
      <div className="mt-4 flex items-center justify-between">
        <h2 className="font-display text-3xl">Trails</h2>
        <button type="button" className="text-xs text-muted" onClick={() => state.toggleSound()}>
          Sound {state.sound ? "on" : "off"}
        </button>
      </div>
      <p className="text-sm text-muted">Best haul {formatCount(state.stats.bestCoins)} coins · {formatCount(state.stats.bestDistance)} m</p>
      <div className="mt-3 grid gap-3">
        {TRACKS.map((trail) => {
          const locked = state.stats.finishes < trail.unlockFinishes
          const selected = trail.id === trackId
          return (
            <button
              key={trail.id}
              type="button"
              disabled={locked}
              onClick={() => onTrack(trail.id)}
              className={`rounded-3xl border p-4 text-left ${selected ? "border-copper bg-panel" : "border-white/10 bg-panel-2"} disabled:opacity-50`}
            >
              <p className="font-display text-2xl leading-none">{trail.name}</p>
              <p className="mt-1 text-sm text-muted">{locked ? "Finish Switchback once to open this wash." : trail.blurb}</p>
            </button>
          )
        })}
      </div>
      <Button className="mt-4 w-full" size="lg" onClick={onStart}>
        Run {TRACKS.find((item) => item.id === trackId)?.name}
      </Button>
      <h2 className="mt-6 font-display text-3xl">Quests</h2>
      <ul className="mt-2 space-y-2 pb-6">
        {quests.map((quest) => (
          <li key={quest.id} className="rounded-2xl bg-panel p-3">
            <div className="flex items-baseline justify-between gap-3">
              <p className="font-semibold">{quest.title}</p>
              <p className="text-xs text-muted">{quest.done ? "Done" : `${quest.value}/${quest.goal}`}</p>
            </div>
            <p className="text-sm text-muted">{quest.detail}</p>
            <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-ink">
              <div className="h-full bg-copper" style={{ width: `${(quest.value / quest.goal) * 100}%` }} />
            </div>
          </li>
        ))}
      </ul>
    </div>
  )
}

function localDay() {
  const date = new Date()
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
}

function RunView({ track, onDone }: { track: (typeof TRACKS)[number]; onDone: (payout: RunPayout, notes: string[]) => void }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const stateRef = useRef<RunState>(createRun())
  const inputRef = useRef<-1 | 0 | 1>(0)
  const pausedRef = useRef(false)
  const settled = useRef(false)
  const dust = useRef<Dust[]>([])
  const onDoneRef = useRef(onDone)
  onDoneRef.current = onDone
  const look = lookOf(useGame((s) => s.loadouts[s.truckId]))
  const lookRef = useRef(look)
  lookRef.current = look
  const sound = useGame((s) => s.sound)
  const soundRef = useRef(sound)
  soundRef.current = sound
  const [paused, setPaused] = useState(false)
  const [hint, setHint] = useState(true)
  const [hud, setHud] = useState({ distance: 0, coins: 0, hits: 3, progress: 0 })

  useEffect(() => {
    useGame.getState().setRunActive(true)
    const timer = window.setTimeout(() => setHint(false), 4500)
    return () => {
      window.clearTimeout(timer)
      useGame.getState().setRunActive(false)
      if (!settled.current && stateRef.current.z > 20) {
        settled.current = true
        useGame.getState().applyRun(settleRun(bailRun(stateRef.current), track), true)
      }
    }
  }, [track])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const parent = canvas.parentElement
    if (!parent) return
    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 1.75)
      canvas.width = Math.max(1, Math.floor(parent.clientWidth * dpr))
      canvas.height = Math.max(1, Math.floor(parent.clientHeight * dpr))
    }
    resize()
    const observer = new ResizeObserver(resize)
    observer.observe(parent)
    let frame = 0
    let last = performance.now()
    let hudAt = 0
    const loop = (now: number) => {
      const dt = Math.min(0.033, (now - last) / 1000)
      last = now
      if (!pausedRef.current && !settled.current) {
        const move = inputRef.current
        inputRef.current = 0
        const stepped = stepRun(stateRef.current, track, { move }, dt)
        stateRef.current = stepped.state
        for (const event of stepped.events) {
          if (event.type === "coin") playTone(soundRef.current, 880, 0.05, 0.03)
          if (event.type === "hit") playTone(soundRef.current, 90, 0.12, 0.05)
          if (event.type === "finish") playTone(soundRef.current, 520, 0.14, 0.04)
        }
        if (stepped.state.status !== "running") {
          settled.current = true
          const payout = settleRun(stepped.state, track)
          const questNotes = useGame.getState().applyRun(payout, false)
          onDoneRef.current(payout, questNotes)
          return
        }
      }
      const ctx = canvas.getContext("2d")
      if (ctx) {
        const dpr = canvas.width / Math.max(1, canvas.clientWidth)
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
        drawRun(ctx, canvas.clientWidth, canvas.clientHeight, stateRef.current, track, lookRef.current, now / 1000, dust.current)
      }
      if (now - hudAt > 100) {
        hudAt = now
        setHud({
          distance: Math.floor(stateRef.current.z),
          coins: previewCoins(stateRef.current),
          hits: 3 - stateRef.current.hits,
          progress: Math.min(1, stateRef.current.z / track.length),
        })
      }
      frame = requestAnimationFrame(loop)
    }
    frame = requestAnimationFrame(loop)
    return () => {
      cancelAnimationFrame(frame)
      observer.disconnect()
    }
  }, [track])

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.repeat) return
      if (event.key === "ArrowLeft" || event.key === "a" || event.key === "A") inputRef.current = -1
      if (event.key === "ArrowRight" || event.key === "d" || event.key === "D") inputRef.current = 1
      if (event.key === "Escape") {
        pausedRef.current = !pausedRef.current
        setPaused(pausedRef.current)
      }
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [])

  const tap = (event: PointerEvent<HTMLCanvasElement>) => {
    const rect = event.currentTarget.getBoundingClientRect()
    inputRef.current = event.clientX - rect.left < rect.width / 2 ? -1 : 1
  }

  return (
    <div className="relative h-full bg-[#1a120e]">
      <canvas ref={canvasRef} className="h-full w-full touch-none" onPointerDown={tap} aria-label="Trail run. Tap the left or right half to change lanes." />
      <div className="pointer-events-none absolute inset-x-0 top-0 h-1 bg-white/10">
        <div className="h-full bg-copper" style={{ width: `${hud.progress * 100}%` }} />
      </div>
      <div className="pointer-events-none absolute inset-x-0 top-[max(0.75rem,env(safe-area-inset-top))] flex justify-between px-4 text-cream">
        <div>
          <p className="text-[11px] uppercase tracking-[0.16em]">{track.name}</p>
          <p className="font-display text-4xl leading-none">{hud.distance} m</p>
        </div>
        <div className="text-right">
          <p className="text-[11px] uppercase tracking-[0.16em]">This run</p>
          <p className="font-display text-4xl leading-none text-copper">{hud.coins}</p>
          <p className="text-xs">{Array.from({ length: 3 }, (_, i) => (i < hud.hits ? "●" : "○")).join(" ")}</p>
        </div>
      </div>
      {hint ? <p className="pointer-events-none absolute bottom-24 left-0 right-0 text-center text-sm text-cream">Tap left or right. Arrows work on a keyboard.</p> : null}
      {paused ? <div className="absolute inset-0 grid place-items-center bg-ink/55 text-3xl font-display">Paused</div> : null}
      <div className="absolute bottom-4 left-4 right-4 flex justify-between">
        <Button
          variant="secondary"
          onClick={() => {
            if (settled.current) return
            settled.current = true
            const payout = settleRun(bailRun(stateRef.current), track)
            const questNotes = useGame.getState().applyRun(payout, false)
            onDoneRef.current(payout, questNotes)
          }}
        >
          Pull off
        </Button>
        <Button
          variant="secondary"
          onClick={() => {
            pausedRef.current = !pausedRef.current
            setPaused(pausedRef.current)
          }}
        >
          {paused ? "Resume" : "Pause"}
        </Button>
      </div>
    </div>
  )
}
