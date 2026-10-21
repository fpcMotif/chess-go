import * as THREE from "three"
import type { Color, PieceSymbol } from "../sim/rules.ts"

export interface Palette {
  readonly robe: number
  readonly trim: number
  readonly skin: number
  readonly hat: number
  readonly accent: number
}

export const PALETTES: Record<Color, Palette> = {
  w: { robe: 0xf1ead9, trim: 0xd9a441, skin: 0xf0c9a5, hat: 0xe6dcc3, accent: 0x8a1c1c },
  b: { robe: 0x2a2b36, trim: 0x3f8f5a, skin: 0xe8b894, hat: 0x1d1e27, accent: 0xc0c0c8 }
}

const material = (color: number, options: { readonly rough?: number; readonly metal?: number } = {}): THREE.MeshStandardMaterial =>
  new THREE.MeshStandardMaterial({ color, roughness: options.rough ?? 0.6, metalness: options.metal ?? 0.05 })

const mesh = (geometry: THREE.BufferGeometry, color: number, options?: { readonly rough?: number; readonly metal?: number }): THREE.Mesh<THREE.BufferGeometry, THREE.MeshStandardMaterial> => {
  const result = new THREE.Mesh(geometry, material(color, options))
  result.castShadow = true
  return result
}

const robe = (palette: Palette, height: number, width: number): THREE.Object3D => {
  const body = mesh(new THREE.ConeGeometry(width, height, 20), palette.robe)
  body.position.y = height / 2
  const hem = mesh(new THREE.TorusGeometry(width * 0.92, 0.03, 8, 24), palette.trim)
  hem.rotation.x = Math.PI / 2
  hem.position.y = 0.04
  const group = new THREE.Group()
  group.add(body, hem)
  return group
}

const head = (palette: Palette, y: number, radius = 0.17): THREE.Object3D => {
  const group = new THREE.Group()
  const face = mesh(new THREE.SphereGeometry(radius, 20, 16), palette.skin, { rough: 0.8 })
  face.position.y = y
  const eyes = new THREE.Group()
  for (const side of [-1, 1]) {
    const eye = mesh(new THREE.SphereGeometry(radius * 0.16, 8, 8), 0x1b1b1b, { rough: 0.3 })
    eye.position.set(side * radius * 0.4, y + radius * 0.12, radius * 0.86)
    eyes.add(eye)
  }
  group.add(face, eyes)
  return group
}

const pointyHat = (palette: Palette, y: number, height: number, brim: number): THREE.Object3D => {
  const group = new THREE.Group()
  const cone = mesh(new THREE.ConeGeometry(brim * 0.55, height, 16), palette.hat)
  cone.position.y = y + height / 2
  cone.rotation.z = 0.12
  const rim = mesh(new THREE.CylinderGeometry(brim, brim, 0.03, 20), palette.hat)
  rim.position.y = y
  const band = mesh(new THREE.CylinderGeometry(brim * 0.5, brim * 0.56, 0.05, 16), palette.trim, { metal: 0.4, rough: 0.35 })
  band.position.y = y + 0.05
  group.add(cone, rim, band)
  return group
}

const wand = (palette: Palette, x: number, y: number): THREE.Object3D => {
  const stick = mesh(new THREE.CylinderGeometry(0.015, 0.02, 0.36, 6), 0x5a3b22, { rough: 0.9 })
  stick.position.set(x, y, 0.12)
  stick.rotation.z = -0.9
  stick.rotation.x = 0.5
  const tip = mesh(new THREE.SphereGeometry(0.03, 8, 8), palette.trim, { metal: 0.6, rough: 0.2 })
  tip.position.set(x + 0.15, y + 0.12, 0.2)
  const group = new THREE.Group()
  group.add(stick, tip)
  return group
}

const scarf = (palette: Palette, y: number, radius: number): THREE.Object3D => {
  const loop = mesh(new THREE.TorusGeometry(radius, 0.04, 8, 20), palette.accent)
  loop.rotation.x = Math.PI / 2
  loop.position.y = y
  return loop
}

const pawn = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(robe(palette, 0.5, 0.22), scarf(palette, 0.47, 0.13), head(palette, 0.6, 0.15), pointyHat(palette, 0.72, 0.32, 0.18), wand(palette, 0.14, 0.4))
  return group
}

const rook = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  const tower = mesh(new THREE.CylinderGeometry(0.22, 0.28, 0.75, 12), palette.robe, { rough: 0.85 })
  tower.position.y = 0.375
  const top = mesh(new THREE.CylinderGeometry(0.27, 0.24, 0.12, 12), palette.hat, { rough: 0.85 })
  top.position.y = 0.8
  group.add(tower, top)
  for (let index = 0; index < 6; index++) {
    const angle = (index / 6) * Math.PI * 2
    const merlon = mesh(new THREE.BoxGeometry(0.1, 0.14, 0.1), palette.hat, { rough: 0.85 })
    merlon.position.set(Math.cos(angle) * 0.21, 0.92, Math.sin(angle) * 0.21)
    group.add(merlon)
  }
  const flag = mesh(new THREE.PlaneGeometry(0.2, 0.12), palette.accent)
  flag.material.side = THREE.DoubleSide
  flag.position.set(0.1, 1.12, 0)
  const pole = mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.4, 6), palette.trim, { metal: 0.5 })
  pole.position.y = 1.05
  const door = mesh(new THREE.BoxGeometry(0.14, 0.22, 0.04), 0x4a2f1a, { rough: 0.95 })
  door.position.set(0, 0.12, 0.27)
  group.add(flag, pole, door)
  return group
}

const knight = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  const broom = mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.9, 8), 0x7a5230, { rough: 0.9 })
  broom.rotation.z = Math.PI / 2
  broom.rotation.y = 0.4
  broom.position.y = 0.45
  const bristles = mesh(new THREE.ConeGeometry(0.11, 0.3, 10), 0xc9a24e, { rough: 0.95 })
  bristles.rotation.z = Math.PI / 2
  bristles.rotation.y = 0.4
  bristles.position.set(-0.5 * Math.cos(0.4), 0.45, 0.5 * Math.sin(0.4))
  const rider = new THREE.Group()
  rider.add(robe(palette, 0.42, 0.18), scarf(palette, 0.4, 0.11), head(palette, 0.52, 0.14), pointyHat(palette, 0.63, 0.3, 0.16))
  rider.position.y = 0.42
  rider.rotation.x = -0.35
  const cape = mesh(new THREE.PlaneGeometry(0.3, 0.4), palette.accent)
  cape.material.side = THREE.DoubleSide
  cape.position.set(-0.18, 0.7, -0.08)
  cape.rotation.y = Math.PI / 2
  cape.rotation.z = 0.6
  group.add(broom, bristles, rider, cape)
  return group
}

const bishop = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(robe(palette, 0.7, 0.24), head(palette, 0.82, 0.16), pointyHat(palette, 0.95, 0.5, 0.2))
  const beard = mesh(new THREE.ConeGeometry(0.1, 0.28, 10), palette.accent, { rough: 0.9 })
  beard.rotation.x = Math.PI
  beard.position.set(0, 0.62, 0.1)
  const staff = mesh(new THREE.CylinderGeometry(0.02, 0.025, 1.0, 8), 0x4a2f1a, { rough: 0.9 })
  staff.position.set(0.28, 0.5, 0.05)
  const orb = mesh(new THREE.SphereGeometry(0.06, 12, 12), palette.trim, { metal: 0.6, rough: 0.2 })
  orb.position.set(0.28, 1.03, 0.05)
  group.add(beard, staff, orb)
  return group
}

const queen = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(robe(palette, 0.8, 0.26), scarf(palette, 0.76, 0.14), head(palette, 0.92, 0.17), pointyHat(palette, 1.06, 0.65, 0.24), wand(palette, 0.2, 0.7))
  const crown = mesh(new THREE.TorusGeometry(0.1, 0.02, 8, 16), palette.trim, { metal: 0.7, rough: 0.25 })
  crown.rotation.x = Math.PI / 2
  crown.position.y = 1.08
  group.add(crown)
  return group
}

const king = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(robe(palette, 0.85, 0.28), head(palette, 0.98, 0.18))
  const beard = mesh(new THREE.ConeGeometry(0.14, 0.55, 12), palette.accent, { rough: 0.9 })
  beard.rotation.x = Math.PI
  beard.position.set(0, 0.68, 0.1)
  const cap = mesh(new THREE.SphereGeometry(0.19, 16, 12, 0, Math.PI * 2, 0, Math.PI / 2), palette.hat)
  cap.position.y = 1.0
  const crown = new THREE.Group()
  for (let index = 0; index < 5; index++) {
    const angle = (index / 5) * Math.PI * 2
    const spike = mesh(new THREE.ConeGeometry(0.035, 0.14, 6), palette.trim, { metal: 0.7, rough: 0.25 })
    spike.position.set(Math.cos(angle) * 0.14, 1.22, Math.sin(angle) * 0.14)
    crown.add(spike)
  }
  const ring = mesh(new THREE.TorusGeometry(0.14, 0.025, 8, 20), palette.trim, { metal: 0.7, rough: 0.25 })
  ring.rotation.x = Math.PI / 2
  ring.position.y = 1.16
  const staff = mesh(new THREE.CylinderGeometry(0.022, 0.028, 1.2, 8), 0x3b2415, { rough: 0.9 })
  staff.position.set(0.3, 0.6, 0.05)
  const gem = mesh(new THREE.OctahedronGeometry(0.08), palette.accent, { metal: 0.3, rough: 0.2 })
  gem.position.set(0.3, 1.26, 0.05)
  group.add(beard, cap, crown, ring, staff, gem)
  return group
}

const BUILDERS = { p: pawn, r: rook, n: knight, b: bishop, q: queen, k: king } satisfies Record<PieceSymbol, (palette: Palette) => THREE.Group>

export const buildCharacter = (color: Color, kind: PieceSymbol): THREE.Group => {
  const figure = BUILDERS[kind](PALETTES[color])
  figure.rotation.y = color === "w" ? 0 : Math.PI
  return figure
}

export const disposeCharacter = (figure: THREE.Object3D): void => {
  figure.traverse((child) => {
    if (child instanceof THREE.Mesh) {
      const materials: Array<unknown> = Array.isArray(child.material) ? child.material : [child.material]
      for (const item of materials) if (item instanceof THREE.Material) item.dispose()
    }
  })
}
