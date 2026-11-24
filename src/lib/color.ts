export function shadeHex(hex: string, amount: number): string {
  const raw = hex.replace("#", "")
  const num = Number.parseInt(raw, 16)
  if (!Number.isFinite(num) || raw.length !== 6) return hex
  const clamp = (channel: number) => Math.max(0, Math.min(255, channel))
  const r = clamp(((num >> 16) & 255) + amount)
  const g = clamp(((num >> 8) & 255) + amount)
  const b = clamp((num & 255) + amount)
  return `#${((r << 16) | (g << 8) | b).toString(16).padStart(6, "0")}`
}
