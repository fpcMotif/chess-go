import * as THREE from "three"
import type { Color, PieceSymbol } from "../sim/rules.ts"
import bb from "../assets/pieces/bb.jpg"
import bk from "../assets/pieces/bk.jpg"
import bn from "../assets/pieces/bn.jpg"
import bp from "../assets/pieces/bp.jpg"
import bq from "../assets/pieces/bq.jpg"
import br from "../assets/pieces/br.jpg"
import wb from "../assets/pieces/wb.jpg"
import wk from "../assets/pieces/wk.jpg"
import wn from "../assets/pieces/wn.jpg"
import wp from "../assets/pieces/wp.jpg"
import wq from "../assets/pieces/wq.jpg"
import wr from "../assets/pieces/wr.jpg"

export interface Palette {
  readonly robe: number
  readonly glow: number
}

export const PALETTES: Record<Color, Palette> = {
  w: { robe: 0xfef3c7, glow: 0xffc174 },
  b: { robe: 0x2c3140, glow: 0x4edea3 }
}

const SOURCES: Record<Color, Record<PieceSymbol, string>> = {
  w: { p: wp, r: wr, n: wn, b: wb, q: wq, k: wk },
  b: { p: bp, r: br, n: bn, b: bb, q: bq, k: bk }
}

const HEIGHTS: Record<PieceSymbol, number> = { p: 1.15, r: 1.2, n: 1.3, b: 1.35, q: 1.45, k: 1.5 }

const KEY_FULL = 110
const KEY_EDGE = 60

const keyOutGreen = (image: HTMLImageElement): THREE.CanvasTexture => {
  const canvas = document.createElement("canvas")
  canvas.width = image.naturalWidth
  canvas.height = image.naturalHeight
  const context = canvas.getContext("2d")
  if (context === null) throw new Error("2d canvas unavailable")
  context.drawImage(image, 0, 0)
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height)
  const data = pixels.data
  for (let index = 0; index < data.length; index += 4) {
    const red = data[index] ?? 0
    const green = data[index + 1] ?? 0
    const blue = data[index + 2] ?? 0
    const spill = green - Math.max(red, blue)
    if (spill >= KEY_FULL) {
      data[index + 3] = 0
    } else if (spill > KEY_EDGE) {
      data[index + 3] = Math.round(255 * (1 - (spill - KEY_EDGE) / (KEY_FULL - KEY_EDGE)))
      data[index + 1] = Math.max(red, blue)
    }
  }
  context.putImageData(pixels, 0, 0)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.anisotropy = 4
  return texture
}

const textures = new Map<string, THREE.CanvasTexture>()

const loadImage = (source: string): Promise<HTMLImageElement> =>
  new Promise((resolve, reject) => {
    const image = new Image()
    image.onload = () => resolve(image)
    image.onerror = () => reject(new Error(`could not load ${source}`))
    image.src = source
  })

export const loadCharacters = async (): Promise<void> => {
  const jobs: Array<Promise<void>> = []
  for (const colorSources of Object.values(SOURCES)) {
    for (const source of Object.values(colorSources)) {
      if (textures.has(source)) continue
      jobs.push(loadImage(source).then((image) => void textures.set(source, keyOutGreen(image))))
    }
  }
  await Promise.all(jobs)
}

export const buildCharacter = (color: Color, kind: PieceSymbol): THREE.Group => {
  const source = SOURCES[color][kind]
  const map = textures.get(source)
  if (map === undefined) throw new Error("characters not loaded")
  const height = HEIGHTS[kind]
  const card = new THREE.Mesh(
    new THREE.PlaneGeometry(height, height),
    new THREE.MeshStandardMaterial({
      map,
      emissive: 0xffffff,
      emissiveMap: map,
      emissiveIntensity: 0.28,
      transparent: true,
      alphaTest: 0.45,
      roughness: 0.95,
      metalness: 0,
      side: THREE.DoubleSide
    })
  )
  card.position.y = height / 2 - 0.02
  card.rotation.order = "YXZ"
  card.castShadow = true
  card.userData = { billboard: true }
  const group = new THREE.Group()
  group.add(card)
  return group
}

const cameraPosition = new THREE.Vector3()
const worldPosition = new THREE.Vector3()

export const faceCamera = (root: THREE.Object3D, camera: THREE.Camera): void => {
  camera.getWorldPosition(cameraPosition)
  root.traverse((object) => {
    if (object.userData["billboard"] !== true) return
    object.getWorldPosition(worldPosition)
    const dx = cameraPosition.x - worldPosition.x
    const dz = cameraPosition.z - worldPosition.z
    const dy = cameraPosition.y - worldPosition.y
    object.rotation.y = Math.atan2(dx, dz)
    object.rotation.x = -Math.atan2(dy, Math.hypot(dx, dz)) * 0.45
  })
}

export const disposeCharacter = (figure: THREE.Object3D): void => {
  figure.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return
    object.geometry.dispose()
    const materials: Array<THREE.Material> = Array.isArray(object.material) ? object.material : [object.material]
    for (const material of materials) material.dispose()
  })
}
