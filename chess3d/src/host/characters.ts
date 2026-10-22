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
import bbBack from "../assets/pieces/bb-back.jpg"
import bkBack from "../assets/pieces/bk-back.jpg"
import bnBack from "../assets/pieces/bn-back.jpg"
import bpBack from "../assets/pieces/bp-back.jpg"
import bqBack from "../assets/pieces/bq-back.jpg"
import brBack from "../assets/pieces/br-back.jpg"
import wbBack from "../assets/pieces/wb-back.jpg"
import wkBack from "../assets/pieces/wk-back.jpg"
import wnBack from "../assets/pieces/wn-back.jpg"
import wpBack from "../assets/pieces/wp-back.jpg"
import wqBack from "../assets/pieces/wq-back.jpg"
import wrBack from "../assets/pieces/wr-back.jpg"

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

const BACKS: Record<Color, Record<PieceSymbol, string>> = {
  w: { p: wpBack, r: wrBack, n: wnBack, b: wbBack, q: wqBack, k: wkBack },
  b: { p: bpBack, r: brBack, n: bnBack, b: bbBack, q: bqBack, k: bkBack }
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
  for (const colorSources of [...Object.values(SOURCES), ...Object.values(BACKS)]) {
    for (const source of Object.values(colorSources)) {
      if (textures.has(source)) continue
      jobs.push(loadImage(source).then((image) => void textures.set(source, keyOutGreen(image))))
    }
  }
  await Promise.all(jobs)
}

const cardMaterial = (map: THREE.Texture): THREE.MeshStandardMaterial =>
  new THREE.MeshStandardMaterial({
    map,
    emissive: 0xffffff,
    emissiveMap: map,
    emissiveIntensity: 0.28,
    transparent: true,
    alphaTest: 0.45,
    roughness: 0.95,
    metalness: 0,
    side: THREE.FrontSide
  })

interface Card {
  readonly front: THREE.MeshStandardMaterial
  readonly back: THREE.MeshStandardMaterial
  readonly facing: number
}

const FACING: Record<Color, number> = { w: Math.PI, b: 0 }

export const buildCharacter = (color: Color, kind: PieceSymbol): THREE.Group => {
  const source = SOURCES[color][kind]
  const map = textures.get(source)
  if (map === undefined) throw new Error("characters not loaded")
  const backMap = textures.get(BACKS[color][kind])
  if (backMap === undefined) throw new Error("characters not loaded")
  const height = HEIGHTS[kind]
  const card: Card = { front: cardMaterial(map), back: cardMaterial(backMap), facing: FACING[color] }
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(height, height), card.front)
  mesh.position.y = height / 2 - 0.02
  mesh.rotation.order = "YXZ"
  mesh.castShadow = true
  mesh.userData = { card }
  const group = new THREE.Group()
  group.add(mesh)
  return group
}

const cameraPosition = new THREE.Vector3()
const worldPosition = new THREE.Vector3()

const wrapAngle = (angle: number): number => Math.atan2(Math.sin(angle), Math.cos(angle))

export const faceCamera = (root: THREE.Object3D, camera: THREE.Camera): void => {
  camera.getWorldPosition(cameraPosition)
  root.traverse((object) => {
    const card = object.userData["card"] as Card | undefined
    if (card === undefined || !(object instanceof THREE.Mesh)) return
    object.getWorldPosition(worldPosition)
    const dx = cameraPosition.x - worldPosition.x
    const dz = cameraPosition.z - worldPosition.z
    const dy = cameraPosition.y - worldPosition.y
    const toCamera = Math.atan2(dx, dz)
    object.rotation.y = toCamera
    object.rotation.x = -Math.atan2(dy, Math.hypot(dx, dz)) * 0.45
    const seenFromBehind = Math.abs(wrapAngle(toCamera - card.facing)) > Math.PI / 2
    object.material = seenFromBehind ? card.back : card.front
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
