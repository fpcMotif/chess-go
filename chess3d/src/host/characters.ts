import * as THREE from "three"
import type { Color, PieceSymbol } from "../sim/rules.ts"

export interface Palette {
  readonly robe: number
  readonly robeDeep: number
  readonly trim: number
  readonly skin: number
  readonly hat: number
  readonly scarf: number
  readonly hair: number
  readonly glow: number
}

export const PALETTES: Record<Color, Palette> = {
  w: { robe: 0xfef3c7, robeDeep: 0xe3cf9a, trim: 0xf59e0b, skin: 0xf2cfae, hat: 0xf3e6c4, scarf: 0xdc2626, hair: 0xf7f1e6, glow: 0xffc174 },
  b: { robe: 0x2c3140, robeDeep: 0x1f2937, trim: 0x10b981, skin: 0xe9bf9d, hat: 0x232838, scarf: 0x94a3b8, hair: 0xd6d9e0, glow: 0x4edea3 }
}

type Options = { readonly rough?: number; readonly metal?: number; readonly emissive?: number; readonly emissiveIntensity?: number }

const material = (color: number, options: Options = {}): THREE.MeshStandardMaterial =>
  new THREE.MeshStandardMaterial({
    color,
    roughness: options.rough ?? 0.6,
    metalness: options.metal ?? 0.05,
    emissive: options.emissive ?? 0x000000,
    emissiveIntensity: options.emissiveIntensity ?? 1
  })

const mesh = (geometry: THREE.BufferGeometry, color: number, options?: Options): THREE.Mesh<THREE.BufferGeometry, THREE.MeshStandardMaterial> => {
  const result = new THREE.Mesh(geometry, material(color, options))
  result.castShadow = true
  return result
}

const base = (palette: Palette, radius: number): THREE.Object3D => {
  const disc = mesh(new THREE.CylinderGeometry(radius, radius * 1.05, 0.08, 24), 0x3a2616, { rough: 0.5 })
  disc.position.y = 0.04
  const rim = mesh(new THREE.TorusGeometry(radius, 0.018, 8, 32), palette.trim, { metal: 0.7, rough: 0.3 })
  rim.rotation.x = Math.PI / 2
  rim.position.y = 0.08
  const group = new THREE.Group()
  group.add(disc, rim)
  return group
}

const robe = (palette: Palette, y: number, height: number, width: number): THREE.Object3D => {
  const body = mesh(new THREE.ConeGeometry(width, height, 24), palette.robe, { rough: 0.7 })
  body.position.y = y + height / 2
  const hem = mesh(new THREE.TorusGeometry(width * 0.94, 0.028, 8, 28), palette.trim, { metal: 0.5, rough: 0.4 })
  hem.rotation.x = Math.PI / 2
  hem.position.y = y + 0.03
  const belt = mesh(new THREE.TorusGeometry(width * 0.5, 0.022, 8, 24), palette.robeDeep)
  belt.rotation.x = Math.PI / 2
  belt.position.y = y + height * 0.5
  const group = new THREE.Group()
  group.add(body, hem, belt)
  return group
}

const head = (palette: Palette, y: number, radius: number, options: { readonly beard?: number; readonly hairColor?: number } = {}): THREE.Object3D => {
  const group = new THREE.Group()
  const face = mesh(new THREE.SphereGeometry(radius, 24, 18), palette.skin, { rough: 0.75 })
  face.position.y = y
  group.add(face)
  for (const side of [-1, 1]) {
    const eye = mesh(new THREE.SphereGeometry(radius * 0.17, 10, 10), 0x1b1b1f, { rough: 0.25 })
    eye.position.set(side * radius * 0.4, y + radius * 0.1, radius * 0.86)
    const shine = mesh(new THREE.SphereGeometry(radius * 0.06, 6, 6), 0xffffff, { rough: 0.2 })
    shine.position.set(side * radius * 0.36, y + radius * 0.17, radius * 1.0)
    const cheek = mesh(new THREE.SphereGeometry(radius * 0.14, 8, 8), 0xf0a0a0, { rough: 0.9 })
    cheek.position.set(side * radius * 0.62, y - radius * 0.12, radius * 0.72)
    cheek.scale.z = 0.3
    group.add(eye, shine, cheek)
  }
  if (options.beard !== undefined) {
    const beard = mesh(new THREE.ConeGeometry(radius * 0.85, options.beard, 14), options.hairColor ?? palette.hair, { rough: 0.95 })
    beard.rotation.x = Math.PI
    beard.position.set(0, y - radius * 0.5 - options.beard / 2 + 0.05, radius * 0.45)
    const moustache = mesh(new THREE.TorusGeometry(radius * 0.4, radius * 0.1, 8, 16, Math.PI), options.hairColor ?? palette.hair, { rough: 0.95 })
    moustache.rotation.z = Math.PI
    moustache.position.set(0, y - radius * 0.25, radius * 0.9)
    group.add(beard, moustache)
  }
  return group
}

const pointyHat = (palette: Palette, y: number, height: number, brim: number, options: { readonly floppy?: boolean } = {}): THREE.Object3D => {
  const group = new THREE.Group()
  const cone = mesh(new THREE.ConeGeometry(brim * 0.55, height, 18), palette.hat, { rough: 0.8 })
  cone.position.y = y + height / 2
  cone.rotation.z = options.floppy === true ? 0.35 : 0.1
  if (options.floppy === true) cone.position.x = -height * 0.12
  const rim = mesh(new THREE.CylinderGeometry(brim, brim * 1.02, 0.035, 24), palette.hat, { rough: 0.8 })
  rim.position.y = y
  if (options.floppy === true) rim.rotation.z = 0.12
  const band = mesh(new THREE.CylinderGeometry(brim * 0.52, brim * 0.58, 0.06, 18), palette.trim, { metal: 0.5, rough: 0.35 })
  band.position.y = y + 0.06
  const buckle = mesh(new THREE.BoxGeometry(0.06, 0.06, 0.02), palette.trim, { metal: 0.8, rough: 0.25 })
  buckle.position.set(0, y + 0.06, brim * 0.56)
  group.add(cone, rim, band, buckle)
  return group
}

const scarf = (palette: Palette, y: number, radius: number): THREE.Object3D => {
  const group = new THREE.Group()
  const loop = mesh(new THREE.TorusGeometry(radius, 0.045, 8, 24), palette.scarf, { rough: 0.9 })
  loop.rotation.x = Math.PI / 2
  loop.position.y = y
  const tail = mesh(new THREE.BoxGeometry(0.08, 0.22, 0.03), palette.scarf, { rough: 0.9 })
  tail.position.set(radius * 0.6, y - 0.12, radius * 0.7)
  tail.rotation.z = 0.2
  group.add(loop, tail)
  return group
}

const wand = (palette: Palette, x: number, y: number, z = 0.12): THREE.Object3D => {
  const group = new THREE.Group()
  const stick = mesh(new THREE.CylinderGeometry(0.014, 0.02, 0.34, 6), 0x5a3b22, { rough: 0.9 })
  stick.position.set(x, y, z)
  stick.rotation.z = -0.9
  stick.rotation.x = 0.5
  const tip = mesh(new THREE.SphereGeometry(0.035, 10, 10), palette.glow, { emissive: palette.glow, emissiveIntensity: 1.6, rough: 0.2 })
  tip.position.set(x + 0.14, y + 0.12, z + 0.08)
  group.add(stick, tip)
  return group
}

const staff = (palette: Palette, x: number, height: number, top: THREE.Mesh): THREE.Object3D => {
  const group = new THREE.Group()
  const pole = mesh(new THREE.CylinderGeometry(0.02, 0.028, height, 8), 0x3f2816, { rough: 0.9 })
  pole.position.set(x, height / 2, 0.06)
  top.position.set(x, height + 0.04, 0.06)
  const collar = mesh(new THREE.TorusGeometry(0.045, 0.012, 8, 16), palette.trim, { metal: 0.7, rough: 0.3 })
  collar.rotation.x = Math.PI / 2
  collar.position.set(x, height - 0.04, 0.06)
  group.add(pole, top, collar)
  return group
}

const sparkles = (palette: Palette, y: number, radius: number, count: number): THREE.Object3D => {
  const group = new THREE.Group()
  for (let index = 0; index < count; index++) {
    const angle = (index / count) * Math.PI * 2
    const spark = mesh(new THREE.OctahedronGeometry(0.03), palette.glow, { emissive: palette.glow, emissiveIntensity: 2, rough: 0.2 })
    spark.position.set(Math.cos(angle) * radius, y + Math.sin(angle * 2) * 0.12, Math.sin(angle) * radius)
    group.add(spark)
  }
  return group
}

const pawn = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(base(palette, 0.3), robe(palette, 0.08, 0.46, 0.21), scarf(palette, 0.5, 0.12), head(palette, 0.64, 0.17), pointyHat(palette, 0.76, 0.3, 0.22, { floppy: true }), wand(palette, 0.14, 0.42))
  return group
}

const rook = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(base(palette, 0.34))
  const tower = mesh(new THREE.CylinderGeometry(0.22, 0.27, 0.72, 14), 0x6d6a66, { rough: 0.9 })
  tower.position.y = 0.44
  const band = mesh(new THREE.TorusGeometry(0.25, 0.02, 8, 24), palette.trim, { metal: 0.6, rough: 0.35 })
  band.rotation.x = Math.PI / 2
  band.position.y = 0.6
  const top = mesh(new THREE.CylinderGeometry(0.28, 0.24, 0.12, 14), 0x5c5955, { rough: 0.9 })
  top.position.y = 0.86
  group.add(tower, band, top)
  for (let index = 0; index < 7; index++) {
    const angle = (index / 7) * Math.PI * 2
    const merlon = mesh(new THREE.BoxGeometry(0.1, 0.14, 0.1), 0x5c5955, { rough: 0.9 })
    merlon.position.set(Math.cos(angle) * 0.22, 0.98, Math.sin(angle) * 0.22)
    merlon.rotation.y = -angle
    group.add(merlon)
  }
  for (let index = 0; index < 3; index++) {
    const slit = mesh(new THREE.BoxGeometry(0.04, 0.12, 0.02), palette.glow, { emissive: palette.glow, emissiveIntensity: 1.4 })
    const angle = (index / 3) * Math.PI * 2 + 0.5
    slit.position.set(Math.cos(angle) * 0.245, 0.55, Math.sin(angle) * 0.245)
    slit.rotation.y = -angle + Math.PI / 2
    group.add(slit)
  }
  const flag = mesh(new THREE.PlaneGeometry(0.22, 0.13), palette.scarf, { rough: 0.9 })
  flag.material.side = THREE.DoubleSide
  flag.position.set(0.11, 1.2, 0)
  const pole = mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.42, 6), palette.trim, { metal: 0.6 })
  pole.position.y = 1.1
  const door = mesh(new THREE.BoxGeometry(0.14, 0.22, 0.04), 0x4a2f1a, { rough: 0.95 })
  door.position.set(0, 0.19, 0.27)
  const arch = mesh(new THREE.TorusGeometry(0.075, 0.02, 8, 12, Math.PI), palette.trim, { metal: 0.5 })
  arch.position.set(0, 0.3, 0.28)
  group.add(flag, pole, door, arch)
  return group
}

const knight = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(base(palette, 0.34))
  const rider = new THREE.Group()
  const broom = mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.0, 8), 0x7a5230, { rough: 0.9 })
  broom.rotation.z = Math.PI / 2
  broom.position.set(0.05, 0, 0)
  const bristles = mesh(new THREE.ConeGeometry(0.11, 0.32, 10), 0xc9a24e, { rough: 0.95 })
  bristles.rotation.z = Math.PI / 2
  bristles.position.set(-0.6, 0, 0)
  const bristleBand = mesh(new THREE.TorusGeometry(0.075, 0.015, 8, 16), palette.trim, { metal: 0.6 })
  bristleBand.rotation.y = Math.PI / 2
  bristleBand.position.set(-0.45, 0, 0)
  const figure = new THREE.Group()
  figure.add(robe(palette, 0, 0.4, 0.17), scarf(palette, 0.38, 0.1), head(palette, 0.5, 0.14), pointyHat(palette, 0.6, 0.3, 0.17))
  figure.position.set(0.05, 0.02, 0)
  figure.rotation.z = -0.5
  const cape = mesh(new THREE.PlaneGeometry(0.42, 0.34), palette.scarf, { rough: 0.9 })
  cape.material.side = THREE.DoubleSide
  cape.position.set(-0.3, 0.3, 0)
  cape.rotation.z = -0.35
  cape.rotation.y = Math.PI / 2
  const trail = new THREE.Group()
  for (let index = 0; index < 4; index++) {
    const spark = mesh(new THREE.OctahedronGeometry(0.025), palette.glow, { emissive: palette.glow, emissiveIntensity: 2 })
    spark.position.set(-0.75 - index * 0.12, -0.05 - index * 0.06, (index % 2) * 0.08 - 0.04)
    trail.add(spark)
  }
  rider.add(broom, bristles, bristleBand, figure, cape, trail)
  rider.position.set(0.1, 0.62, 0)
  rider.rotation.z = 0.35
  rider.rotation.y = -0.6
  group.add(rider)
  return group
}

const bishop = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  const crystal = mesh(new THREE.OctahedronGeometry(0.075), palette.glow, { emissive: palette.glow, emissiveIntensity: 2.2, rough: 0.15 })
  crystal.scale.y = 1.5
  group.add(base(palette, 0.32), robe(palette, 0.08, 0.72, 0.24), head(palette, 0.92, 0.17, { beard: 0.34 }), pointyHat(palette, 1.04, 0.5, 0.22), staff(palette, 0.3, 1.1, crystal))
  return group
}

const queen = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  group.add(base(palette, 0.34), robe(palette, 0.08, 0.82, 0.26), scarf(palette, 0.86, 0.14), head(palette, 1.02, 0.18), pointyHat(palette, 1.16, 0.7, 0.25), wand(palette, 0.2, 0.78), sparkles(palette, 0.9, 0.42, 7))
  const circlet = mesh(new THREE.TorusGeometry(0.11, 0.018, 8, 20), palette.trim, { metal: 0.8, rough: 0.2 })
  circlet.rotation.x = Math.PI / 2
  circlet.position.y = 1.17
  const gem = mesh(new THREE.OctahedronGeometry(0.035), palette.glow, { emissive: palette.glow, emissiveIntensity: 1.8 })
  gem.position.set(0, 1.17, 0.11)
  group.add(circlet, gem)
  return group
}

const king = (palette: Palette): THREE.Group => {
  const group = new THREE.Group()
  const book = mesh(new THREE.BoxGeometry(0.5, 0.1, 0.38), palette.scarf, { rough: 0.8 })
  book.position.y = 0.13
  const pages = mesh(new THREE.BoxGeometry(0.46, 0.06, 0.34), 0xf5ecd2, { rough: 0.95 })
  pages.position.y = 0.13
  const gem = mesh(new THREE.OctahedronGeometry(0.085), 0xef4444, { emissive: 0xef4444, emissiveIntensity: 2, rough: 0.15 })
  group.add(base(palette, 0.36), book, pages, robe(palette, 0.18, 0.86, 0.28), head(palette, 1.2, 0.19, { beard: 0.5 }), staff(palette, 0.32, 1.35, gem))
  const cap = mesh(new THREE.SphereGeometry(0.2, 18, 12, 0, Math.PI * 2, 0, Math.PI / 2), palette.hat, { rough: 0.8 })
  cap.position.y = 1.22
  const ring = mesh(new THREE.TorusGeometry(0.15, 0.025, 8, 24), palette.trim, { metal: 0.8, rough: 0.25 })
  ring.rotation.x = Math.PI / 2
  ring.position.y = 1.38
  group.add(cap, ring)
  for (let index = 0; index < 5; index++) {
    const angle = (index / 5) * Math.PI * 2
    const spike = mesh(new THREE.ConeGeometry(0.035, 0.15, 6), palette.trim, { metal: 0.8, rough: 0.25 })
    spike.position.set(Math.cos(angle) * 0.14, 1.46, Math.sin(angle) * 0.14)
    group.add(spike)
  }
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
