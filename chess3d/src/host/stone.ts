import * as THREE from "three"

type Paint = (context: CanvasRenderingContext2D, next: () => number) => void

const randomFrom = (seed: number): (() => number) => {
  let state = seed
  return () => {
    state = (state * 16807) % 2147483647
    return state / 2147483647
  }
}

const canvasTexture = (width: number, height: number, seed: number, paint: Paint, grain: number): THREE.CanvasTexture => {
  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = height
  const context = canvas.getContext("2d")
  if (context === null) throw new Error("2d canvas unavailable")
  const next = randomFrom(seed)
  paint(context, next)
  if (grain > 0) {
    const pixels = context.getImageData(0, 0, width, height)
    for (let index = 0; index < pixels.data.length; index += 4) {
      const shift = (next() - 0.5) * grain
      for (let channel = 0; channel < 3; channel++) pixels.data[index + channel] = THREE.MathUtils.clamp((pixels.data[index + channel] ?? 0) + shift, 0, 255)
    }
    context.putImageData(pixels, 0, 0)
  }
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping
  texture.anisotropy = 8
  return texture
}

const splitInto = (total: number, count: number, next: () => number): Array<number> => {
  const parts = Array.from({ length: count }, () => 0.6 + next() * 0.8)
  const sum = parts.reduce((left, right) => left + right, 0)
  return parts.map((part) => (part / sum) * total)
}

const block = (context: CanvasRenderingContext2D, x: number, y: number, width: number, height: number, inset: number, size: number): void => {
  for (const shift of [-size, 0, size]) context.fillRect(x + shift + inset, y + inset, width - inset * 2, height - inset * 2)
}

const stain = (context: CanvasRenderingContext2D, next: () => number, size: number, count: number, color: string): void => {
  for (let index = 0; index < count; index++) {
    const x = next() * size
    const y = next() * size
    const radius = 20 + next() * 70
    const gradient = context.createRadialGradient(x, y, 0, x, y, radius)
    gradient.addColorStop(0, color)
    gradient.addColorStop(1, "rgba(0,0,0,0)")
    context.fillStyle = gradient
    context.fillRect(x - radius, y - radius, radius * 2, radius * 2)
  }
}

export const limestoneTexture = (): THREE.CanvasTexture =>
  canvasTexture(
    512,
    512,
    41,
    (context, next) => {
      context.fillStyle = "#a8957a"
      context.fillRect(0, 0, 512, 512)
      for (let row = 0; row < 8; row++) {
        const shift = next() * 512
        let x = shift
        for (const width of splitInto(512, 4, next)) {
          context.fillStyle = `hsl(${37 + next() * 4}, ${24 + next() * 6}%, ${63 + next() * 7}%)`
          block(context, x % 512, row * 64, width, 64, 2, 512)
          x += width
        }
      }
      stain(context, next, 512, 14, "rgba(90,70,45,0.12)")
      stain(context, next, 512, 8, "rgba(255,245,220,0.12)")
    },
    34
  )

export const flagstoneTexture = (): THREE.CanvasTexture =>
  canvasTexture(
    512,
    512,
    97,
    (context, next) => {
      context.fillStyle = "#5c5446"
      context.fillRect(0, 0, 512, 512)
      let y = 0
      for (const height of splitInto(512, 4, next)) {
        let x = next() * 512
        for (const width of splitInto(512, 3, next)) {
          context.fillStyle = `hsl(${34 + next() * 10}, ${10 + next() * 10}%, ${54 + next() * 14}%)`
          block(context, x % 512, y, width, height, 3, 512)
          x += width
        }
        y += height
      }
      stain(context, next, 512, 18, "rgba(60,50,35,0.16)")
      stain(context, next, 512, 10, "rgba(255,250,235,0.1)")
    },
    26
  )

const lattice = (context: CanvasRenderingContext2D, width: number, height: number, spacing: number, line: number, color: string): void => {
  context.strokeStyle = color
  context.lineWidth = line
  for (let offset = -height; offset < width + height; offset += spacing) {
    context.beginPath()
    context.moveTo(offset, 0)
    context.lineTo(offset + height, height)
    context.moveTo(offset, height)
    context.lineTo(offset + height, 0)
    context.stroke()
  }
}

export const leadedGlassTexture = (): THREE.CanvasTexture =>
  canvasTexture(
    256,
    512,
    5,
    (context, next) => {
      const sky = context.createLinearGradient(0, 0, 0, 512)
      sky.addColorStop(0, "#fffdf6")
      sky.addColorStop(0.55, "#f3f6ef")
      sky.addColorStop(1, "#cfdcc0")
      context.fillStyle = sky
      context.fillRect(0, 0, 256, 512)
      for (let index = 0; index < 10; index++) {
        const x = next() * 256
        const y = 330 + next() * 180
        const radius = 40 + next() * 60
        const leaf = context.createRadialGradient(x, y, 0, x, y, radius)
        leaf.addColorStop(0, "rgba(120,150,90,0.35)")
        leaf.addColorStop(1, "rgba(120,150,90,0)")
        context.fillStyle = leaf
        context.fillRect(x - radius, y - radius, radius * 2, radius * 2)
      }
      lattice(context, 256, 512, 20, 1.5, "rgba(70,62,52,0.8)")
      context.fillStyle = "rgba(150,135,110,1)"
      context.fillRect(123, 0, 10, 512)
      context.fillRect(0, 249, 256, 6)
      context.fillRect(0, 0, 256, 6)
      context.fillRect(0, 0, 6, 512)
      context.fillRect(250, 0, 6, 512)
    },
    6
  )

export const lightPatchTexture = (): THREE.CanvasTexture => {
  const texture = canvasTexture(
    256,
    512,
    9,
    (context) => {
      context.fillStyle = "#000"
      context.fillRect(0, 0, 256, 512)
      const glow = context.createRadialGradient(128, 256, 30, 128, 256, 250)
      glow.addColorStop(0, "#fff")
      glow.addColorStop(0.7, "#ddd")
      glow.addColorStop(1, "#000")
      context.fillStyle = glow
      context.fillRect(0, 0, 256, 512)
      lattice(context, 256, 512, 28, 4, "#000")
      context.fillStyle = "#000"
      context.fillRect(122, 0, 12, 512)
      context.fillRect(0, 248, 256, 12)
    },
    0
  )
  texture.wrapS = texture.wrapT = THREE.ClampToEdgeWrapping
  return texture
}

export const shaftTexture = (): THREE.CanvasTexture => {
  const texture = canvasTexture(
    64,
    256,
    3,
    (context) => {
      const across = context.createLinearGradient(0, 0, 64, 0)
      across.addColorStop(0, "#000")
      across.addColorStop(0.5, "#fff")
      across.addColorStop(1, "#000")
      context.fillStyle = across
      context.fillRect(0, 0, 64, 256)
      const along = context.createLinearGradient(0, 0, 0, 256)
      along.addColorStop(0, "rgba(0,0,0,0.85)")
      along.addColorStop(0.25, "rgba(0,0,0,0)")
      along.addColorStop(0.8, "rgba(0,0,0,0.2)")
      along.addColorStop(1, "rgba(0,0,0,1)")
      context.fillStyle = along
      context.fillRect(0, 0, 64, 256)
    },
    0
  )
  texture.wrapS = texture.wrapT = THREE.ClampToEdgeWrapping
  return texture
}
