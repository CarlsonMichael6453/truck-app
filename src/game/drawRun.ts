import type { Track } from "../content/types"
import { shadeHex } from "../lib/color"
import type { RunState } from "./runner"

export type RunLook = {
  paint: string
  accent: string
  lift: number
  tireScale: number
  light: "pods" | "bar" | "dual"
  spoiler: "none" | "lip" | "wing"
  stripe: boolean
}

export type Dust = { x: number; y: number; life: number; size: number }

function project(width: number, height: number, ahead: number, lateral: number) {
  const z = ahead + 3.2
  const scale = 3.2 / z
  const horizon = height * 0.42
  const playerY = height * 0.78
  return {
    x: width * 0.5 + lateral * width * 0.3 * scale,
    y: horizon + (playerY - horizon) * scale,
    s: scale,
  }
}

export function drawRun(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  state: RunState,
  track: Track,
  look: RunLook,
  time: number,
  dust: Dust[],
) {
  const sky = ctx.createLinearGradient(0, 0, 0, height)
  sky.addColorStop(0, "#24160f")
  sky.addColorStop(0.38, "#c45a32")
  sky.addColorStop(0.58, "#f0b15a")
  sky.addColorStop(1, "#6a4632")
  ctx.fillStyle = sky
  ctx.fillRect(0, 0, width, height)

  const sun = ctx.createRadialGradient(width * 0.72, height * 0.4, 8, width * 0.72, height * 0.4, width * 0.34)
  sun.addColorStop(0, "rgba(255,236,200,0.95)")
  sun.addColorStop(1, "rgba(255,170,80,0)")
  ctx.fillStyle = sun
  ctx.beginPath()
  ctx.arc(width * 0.72, height * 0.4, width * 0.34, 0, Math.PI * 2)
  ctx.fill()

  drawMesa(ctx, width, height, state.z * 0.15, "#31425c", 0.34)
  drawMesa(ctx, width, height, state.z * 0.28, "#6a4034", 0.4)

  for (let i = 16; i >= 0; i -= 1) {
    const a0 = i * 3.2
    const a1 = (i + 1) * 3.2
    const stripe = Math.floor((state.z + a0) / 6) % 2 === 0
    roadQuad(ctx, width, height, a0, a1, -1.7, 1.7, stripe ? "#3a342f" : "#463e38")
    roadQuad(ctx, width, height, a0, a1, -3.4, -1.7, "#8a6244")
    roadQuad(ctx, width, height, a0, a1, 1.7, 3.4, "#8a6244")
  }

  const entities = track.entities
    .map((entity) => ({ entity, ahead: entity.z - state.z }))
    .filter((item) => item.ahead > -1 && item.ahead < 58)
    .sort((a, b) => b.ahead - a.ahead)
  for (const item of entities) {
    if (state.resolved[item.entity.id] && item.entity.kind === "coin") continue
    const p = project(width, height, item.ahead, item.entity.lane - 1)
    drawEntity(ctx, item.entity.kind, p.x, p.y, p.s * Math.min(width, 520) / 390, time)
  }

  const player = project(width, height, 0.35, state.lanePos - 1)
  const unit = Math.min(width, 520) / 390
  drawTruck(ctx, player.x, player.y + 10 * unit, unit, look, state.z)
  if (dust.length < 40 && Math.random() < 0.8) {
    dust.push({ x: player.x + (Math.random() - 0.5) * 20, y: player.y + 8, life: 0.6, size: 4 + Math.random() * 6 })
  }
  for (let i = dust.length - 1; i >= 0; i -= 1) {
    const mote = dust[i]!
    mote.life -= 0.016
    mote.y -= 0.4
    mote.x += Math.sin(time + i) * 0.3
    if (mote.life <= 0) dust.splice(i, 1)
    else {
      ctx.fillStyle = `rgba(214,176,120,${mote.life})`
      ctx.beginPath()
      ctx.arc(mote.x, mote.y, mote.size * mote.life, 0, Math.PI * 2)
      ctx.fill()
    }
  }
}

function drawMesa(ctx: CanvasRenderingContext2D, width: number, height: number, shift: number, color: string, y: number) {
  ctx.fillStyle = color
  ctx.beginPath()
  ctx.moveTo(0, height * y)
  for (let i = 0; i <= 8; i += 1) {
    const x = ((i * width) / 8 - (shift % width) + width) % (width + 80) - 40
    ctx.lineTo(x, height * (y - 0.05 - (i % 3) * 0.03))
    ctx.lineTo(x + 50, height * y)
  }
  ctx.lineTo(width, height * 0.5)
  ctx.lineTo(0, height * 0.5)
  ctx.fill()
}

function roadQuad(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  a0: number,
  a1: number,
  lat0: number,
  lat1: number,
  color: string,
) {
  const p0 = project(width, height, a0, lat0)
  const p1 = project(width, height, a0, lat1)
  const p2 = project(width, height, a1, lat1)
  const p3 = project(width, height, a1, lat0)
  ctx.fillStyle = color
  ctx.beginPath()
  ctx.moveTo(p0.x, p0.y)
  ctx.lineTo(p1.x, p1.y)
  ctx.lineTo(p2.x, p2.y)
  ctx.lineTo(p3.x, p3.y)
  ctx.fill()
}

function drawEntity(ctx: CanvasRenderingContext2D, kind: string, x: number, y: number, s: number, time: number) {
  if (kind === "coin") {
    ctx.fillStyle = "#f2c56e"
    ctx.beginPath()
    ctx.arc(x, y - 18 * s, 8 * s, 0, Math.PI * 2)
    ctx.fill()
    ctx.strokeStyle = "#8a5a18"
    ctx.lineWidth = 2
    ctx.stroke()
    return
  }
  if (kind === "mud") {
    ctx.fillStyle = "rgba(58,42,28,0.85)"
    ctx.beginPath()
    ctx.ellipse(x, y, 22 * s, 8 * s, 0, 0, Math.PI * 2)
    ctx.fill()
    return
  }
  if (kind === "boost") {
    ctx.strokeStyle = "#b6e38a"
    ctx.lineWidth = 3 * s
    ctx.beginPath()
    ctx.moveTo(x - 10 * s, y)
    ctx.lineTo(x, y - 14 * s)
    ctx.lineTo(x + 10 * s, y)
    ctx.stroke()
    return
  }
  if (kind === "barrier") {
    ctx.fillStyle = "#e7c15a"
    round(ctx, x - 16 * s, y - 28 * s, 32 * s, 26 * s, 3)
    ctx.fill()
    ctx.fillStyle = "#1c1a16"
    ctx.fillRect(x - 16 * s, y - 18 * s, 32 * s, 6 * s)
    return
  }
  ctx.fillStyle = "#5c5148"
  ctx.beginPath()
  ctx.moveTo(x - 16 * s, y)
  ctx.lineTo(x - 8 * s, y - 20 * s)
  ctx.lineTo(x + 6 * s, y - 26 * s)
  ctx.lineTo(x + 18 * s, y - 8 * s)
  ctx.lineTo(x + 10 * s, y)
  ctx.closePath()
  ctx.fill()
  void time
}

function drawTruck(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, look: RunLook, spin: number) {
  const wheelR = 16 * s * look.tireScale
  const lift = look.lift * 34 * s
  const bodyW = 86 * s
  const bodyH = 30 * s
  const bodyBottom = y - lift
  const bodyTop = bodyBottom - bodyH
  ctx.fillStyle = "rgba(0,0,0,0.28)"
  ctx.beginPath()
  ctx.ellipse(x, y + 6 * s, bodyW * 0.42, 7 * s, 0, 0, Math.PI * 2)
  ctx.fill()
  for (const side of [-1, 1]) {
    const wx = x + side * bodyW * 0.3
    const wy = y - wheelR * 0.15
    ctx.fillStyle = "#141414"
    ctx.beginPath()
    ctx.arc(wx, wy, wheelR, 0, Math.PI * 2)
    ctx.fill()
    ctx.strokeStyle = "#d5dde6"
    ctx.lineWidth = 2 * s
    ctx.beginPath()
    ctx.moveTo(wx, wy)
    ctx.lineTo(wx + Math.cos(spin) * wheelR * 0.45, wy + Math.sin(spin) * wheelR * 0.45)
    ctx.stroke()
  }
  ctx.fillStyle = look.paint
  round(ctx, x - bodyW / 2, bodyTop, bodyW, bodyH, 7 * s)
  ctx.fill()
  const cabW = bodyW * 0.7
  const cabH = 24 * s
  ctx.fillStyle = shadeHex(look.paint, 18)
  round(ctx, x - cabW / 2, bodyTop - cabH + 4 * s, cabW, cabH, 6 * s)
  ctx.fill()
  ctx.fillStyle = "rgba(180,205,220,0.55)"
  round(ctx, x - cabW * 0.28, bodyTop - cabH + 8 * s, cabW * 0.56, cabH * 0.38, 3 * s)
  ctx.fill()
  ctx.fillStyle = "#ff3b3b"
  round(ctx, x - bodyW / 2 + 4 * s, bodyTop + bodyH * 0.38, 8 * s, 9 * s, 2)
  ctx.fill()
  round(ctx, x + bodyW / 2 - 12 * s, bodyTop + bodyH * 0.38, 8 * s, 9 * s, 2)
  ctx.fill()
  ctx.fillStyle = "#1c1e22"
  round(ctx, x - bodyW / 2 - 3 * s, bodyBottom - 7 * s, bodyW + 6 * s, 8 * s, 3)
  ctx.fill()
  if (look.light === "bar" || look.light === "dual") {
    ctx.fillStyle = "#f4f7ff"
    round(ctx, x - cabW * 0.36, bodyTop - cabH - 4 * s, cabW * 0.72, 4 * s, 2)
    ctx.fill()
  }
  if (look.spoiler === "wing") {
    ctx.fillStyle = "#141414"
    ctx.fillRect(x - bodyW * 0.38, bodyTop - cabH - 12 * s, bodyW * 0.76, 3 * s)
  }
  if (look.stripe) {
    ctx.fillStyle = look.accent
    ctx.fillRect(x - 2.5 * s, bodyTop + 4 * s, 5 * s, bodyH - 8 * s)
  }
}

function round(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath()
  ctx.roundRect(x, y, w, h, r)
}
