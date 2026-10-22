import * as THREE from "three"

export interface Grain {
  readonly dark: number
  readonly light: number
  readonly seed: number
  readonly scale: number
  readonly wobble: number
}

const SIZE = 512

const hash = (x: number, y: number, seed: number): number => {
  const value = Math.sin(x * 12.9898 + y * 78.233 + seed * 37.719) * 43758.5453
  return value - Math.floor(value)
}

export const woodTexture = ({ dark, light, seed, scale, wobble: amplitude }: Grain): THREE.CanvasTexture => {
  const canvas = document.createElement("canvas")
  canvas.width = canvas.height = SIZE
  const context = canvas.getContext("2d")
  if (context === null) throw new Error("2d canvas unavailable")
  const pixels = context.createImageData(SIZE, SIZE)
  const from = new THREE.Color().setHex(dark, THREE.LinearSRGBColorSpace)
  const to = new THREE.Color().setHex(light, THREE.LinearSRGBColorSpace)
  const mixed = new THREE.Color()
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const wobble = (Math.sin(y * 0.021 * scale + seed) * 2.1 + Math.sin(y * 0.0071 * scale + x * 0.004 + seed * 2) * 4.5 + Math.sin((x + y) * 0.047 * scale) * 0.6) * amplitude
      const ring = Math.sin(x * 0.085 * scale + wobble)
      const band = Math.pow(0.5 + 0.5 * ring, 1.6)
      const fiber = hash(x, Math.floor(y / 3), seed) * 0.12
      const pore = hash(Math.floor(x / 2), y, seed + 1) < 0.015 ? -0.18 : 0
      const t = THREE.MathUtils.clamp(0.15 + band * 0.75 + fiber + pore, 0, 1)
      mixed.copy(from).lerp(to, t)
      const offset = (y * SIZE + x) * 4
      pixels.data[offset] = Math.round(mixed.r * 255)
      pixels.data[offset + 1] = Math.round(mixed.g * 255)
      pixels.data[offset + 2] = Math.round(mixed.b * 255)
      pixels.data[offset + 3] = 255
    }
  }
  context.putImageData(pixels, 0, 0)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping
  texture.anisotropy = 8
  return texture
}

export const WALNUT: Grain = { dark: 0x2a170b, light: 0x6b4322, seed: 3, scale: 1, wobble: 1 }
export const TILE_GRAIN: Grain = { dark: 0xd8d8d8, light: 0xffffff, seed: 11, scale: 2.6, wobble: 0.3 }
