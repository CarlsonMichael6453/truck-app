import * as THREE from "three"

function canvasTexture(draw: (ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement) => void, width: number, height: number) {
  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext("2d")
  if (!ctx) return new THREE.Texture()
  draw(ctx, canvas)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.anisotropy = 4
  return texture
}

export function makeConcreteTexture() {
  const texture = canvasTexture((ctx) => {
    ctx.fillStyle = "#2a2e34"
    ctx.fillRect(0, 0, 512, 512)
    for (let i = 0; i < 2800; i += 1) {
      const shade = 28 + Math.random() * 36
      ctx.fillStyle = `rgba(${shade},${shade + 2},${shade + 6},0.45)`
      ctx.fillRect(Math.random() * 512, Math.random() * 512, Math.random() * 2.4, Math.random() * 2.4)
    }
    ctx.strokeStyle = "rgba(255,255,255,0.045)"
    ctx.lineWidth = 2
    for (let i = 0; i <= 512; i += 64) {
      ctx.beginPath()
      ctx.moveTo(i, 0)
      ctx.lineTo(i, 512)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(0, i)
      ctx.lineTo(512, i)
      ctx.stroke()
    }
  }, 512, 512)
  texture.wrapS = THREE.RepeatWrapping
  texture.wrapT = THREE.RepeatWrapping
  texture.repeat.set(5, 5)
  return texture
}

export function makeWallTexture() {
  return canvasTexture((ctx) => {
    const gradient = ctx.createLinearGradient(0, 0, 0, 512)
    gradient.addColorStop(0, "#161922")
    gradient.addColorStop(0.55, "#241c18")
    gradient.addColorStop(1, "#3a312b")
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, 32, 512)
  }, 32, 512)
}

export function makeBlobTexture() {
  return canvasTexture((ctx) => {
    const gradient = ctx.createRadialGradient(128, 128, 16, 128, 128, 120)
    gradient.addColorStop(0, "rgba(0,0,0,0.55)")
    gradient.addColorStop(1, "rgba(0,0,0,0)")
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, 256, 256)
  }, 256, 256)
}

export function makePlateTexture(text: string) {
  return canvasTexture((ctx) => {
    ctx.fillStyle = "#efe6c8"
    ctx.fillRect(0, 0, 256, 112)
    ctx.strokeStyle = "#1c1a16"
    ctx.lineWidth = 8
    ctx.strokeRect(6, 6, 244, 100)
    ctx.fillStyle = "#1c1a16"
    ctx.font = "700 48px sans-serif"
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText(text, 128, 60)
  }, 256, 112)
}

export function makeSunsetTexture(accent: string) {
  return canvasTexture((ctx) => {
    const gradient = ctx.createLinearGradient(0, 0, 512, 180)
    gradient.addColorStop(0, "rgba(0,0,0,0)")
    gradient.addColorStop(0.35, accent)
    gradient.addColorStop(1, "rgba(255,214,150,0.05)")
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, 512, 256)
  }, 512, 256)
}

export function makePosterTexture() {
  return canvasTexture((ctx) => {
    ctx.fillStyle = "#1a140f"
    ctx.fillRect(0, 0, 256, 384)
    ctx.fillStyle = "#ff8a3d"
    ctx.fillRect(24, 36, 36, 8)
    ctx.fillStyle = "#f3efe6"
    ctx.font = "700 42px sans-serif"
    ctx.fillText("BAY 04", 24, 110)
    ctx.font = "500 18px sans-serif"
    ctx.fillStyle = "#b7b0a4"
    ctx.fillText("OMNIPRESENT", 24, 150)
    ctx.fillText("FICTIONAL METAL", 24, 176)
  }, 256, 384)
}
