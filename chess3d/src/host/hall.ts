import * as THREE from "three"
import { flagstoneTexture, leadedGlassTexture, lightPatchTexture, limestoneTexture, shaftTexture } from "./stone.ts"
import { woodTexture } from "./wood.ts"

const FLOOR = -3.2
const HALF_WIDTH = 10
const BACK = -18
const FRONT = 14
const WALL_TOP = 8.8
const RIDGE = 14
const BAY = 4
const FLAME = 0xffd27a
const CANDLE = 0xffb95f
const SUN = 0xfff0d8
const HAZE = 0xd9ccb4
const BANNERS = [0x7a1f2b, 0x1f4a33, 0x1e2f5c, 0xb8892a] as const
const OAK = { dark: 0x2e1c10, light: 0x6e4a2c, seed: 5, scale: 0.55, wobble: 0.9 }

export interface Hall {
  readonly group: THREE.Group
  update(time: number): void
}

let cachedGlow: THREE.CanvasTexture | null = null
const glowTexture = (): THREE.CanvasTexture => {
  if (cachedGlow !== null) return cachedGlow
  const canvas = document.createElement("canvas")
  canvas.width = canvas.height = 64
  const context = canvas.getContext("2d")
  if (context !== null) {
    const gradient = context.createRadialGradient(32, 32, 0, 32, 32, 32)
    gradient.addColorStop(0, "rgba(255,255,255,1)")
    gradient.addColorStop(0.4, "rgba(255,255,255,0.35)")
    gradient.addColorStop(1, "rgba(255,255,255,0)")
    context.fillStyle = gradient
    context.fillRect(0, 0, 64, 64)
  }
  cachedGlow = new THREE.CanvasTexture(canvas)
  return cachedGlow
}

const wax = new THREE.MeshStandardMaterial({ color: 0xf3ead3, roughness: 0.7 })
const flameMaterial = new THREE.MeshBasicMaterial({ color: FLAME })

const candle = (height: number): { group: THREE.Group; flame: THREE.Mesh } => {
  const group = new THREE.Group()
  const stick = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.05, height, 10), wax)
  stick.position.y = height / 2
  stick.castShadow = true
  const flame = new THREE.Mesh(new THREE.SphereGeometry(0.04, 8, 8), flameMaterial)
  flame.scale.set(1, 1.9, 1)
  flame.position.y = height + 0.06
  const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTexture(), color: CANDLE, transparent: true, opacity: 0.45, depthWrite: false, blending: THREE.AdditiveBlending }))
  halo.scale.setScalar(0.7)
  halo.position.y = height + 0.08
  group.add(stick, flame, halo)
  return { group, flame }
}

const lancet = (width: number, height: number): THREE.ShapeGeometry => {
  const shape = new THREE.Shape()
  const shoulder = height - width * 0.75
  shape.moveTo(-width / 2, 0)
  shape.lineTo(width / 2, 0)
  shape.lineTo(width / 2, shoulder)
  shape.quadraticCurveTo(width / 2, height - width * 0.15, 0, height)
  shape.quadraticCurveTo(-width / 2, height - width * 0.15, -width / 2, shoulder)
  shape.closePath()
  const geometry = new THREE.ShapeGeometry(shape, 12)
  const position = geometry.getAttribute("position")
  const uv = geometry.getAttribute("uv")
  for (let index = 0; index < position.count; index++) uv.setXY(index, (position.getX(index) + width / 2) / width, position.getY(index) / height)
  return geometry
}

const banner = (color: number): THREE.Group => {
  const width = 1.1
  const length = 4.2
  const shape = new THREE.Shape()
  shape.moveTo(-width / 2, 0)
  shape.lineTo(width / 2, 0)
  shape.lineTo(width / 2, -length)
  shape.lineTo(0, -length - 0.45)
  shape.lineTo(-width / 2, -length)
  shape.closePath()
  const cloth = new THREE.Mesh(new THREE.ShapeGeometry(shape), new THREE.MeshStandardMaterial({ color, roughness: 0.95, side: THREE.DoubleSide }))
  cloth.castShadow = true
  const rod = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, width + 0.4, 8), new THREE.MeshStandardMaterial({ color: 0x2b2622, roughness: 0.5, metalness: 0.7 }))
  rod.rotation.z = Math.PI / 2
  const group = new THREE.Group()
  group.add(cloth, rod)
  return group
}

const fern = (): THREE.Group => {
  const group = new THREE.Group()
  const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.16, 0.34, 14), new THREE.MeshStandardMaterial({ color: 0x9c5232, roughness: 0.85 }))
  pot.position.y = 0.17
  group.add(pot)
  const leaf = new THREE.MeshStandardMaterial({ color: 0x4d7a30, roughness: 0.8, side: THREE.DoubleSide })
  const frond = new THREE.ConeGeometry(0.07, 0.85, 4)
  frond.translate(0, 0.42, 0)
  for (let index = 0; index < 11; index++) {
    const blade = new THREE.Mesh(frond, leaf)
    blade.position.y = 0.3
    blade.rotation.set(0.5 + (index % 3) * 0.25, (index / 11) * Math.PI * 2, 0, "YXZ")
    blade.scale.set(1, 0.8 + (index % 4) * 0.1, 0.35)
    blade.castShadow = true
    group.add(blade)
  }
  return group
}

const box = (width: number, height: number, depth: number, material: THREE.Material, x: number, y: number, z: number): THREE.Mesh => {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material)
  mesh.position.set(x, y, z)
  mesh.castShadow = true
  mesh.receiveShadow = true
  return mesh
}

export const makeHall = (scene: THREE.Scene): Hall => {
  const group = new THREE.Group()
  scene.fog = new THREE.FogExp2(HAZE, 0.011)
  let seed = 7
  const random = (): number => {
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
  }

  const sun = new THREE.DirectionalLight(SUN, 2.4)
  sun.position.set(-14, 17, 5)
  sun.target.position.set(0, FLOOR, 0)
  sun.castShadow = true
  sun.shadow.mapSize.set(2048, 2048)
  sun.shadow.camera.left = sun.shadow.camera.bottom = -16
  sun.shadow.camera.right = sun.shadow.camera.top = 16
  sun.shadow.camera.far = 60
  sun.shadow.bias = -0.0004
  sun.shadow.normalBias = 0.02
  group.add(sun, sun.target)
  const sunDirection = sun.target.position.clone().sub(sun.position).normalize()

  const floorMap = flagstoneTexture()
  floorMap.repeat.set(5, 8)
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(HALF_WIDTH * 2, FRONT - BACK), new THREE.MeshStandardMaterial({ map: floorMap, bumpMap: floorMap, bumpScale: 0.03, roughness: 0.82 }))
  floor.rotation.x = -Math.PI / 2
  floor.position.set(0, FLOOR, (FRONT + BACK) / 2)
  floor.receiveShadow = true
  group.add(floor)

  const wallHeight = WALL_TOP - FLOOR
  const sideMap = limestoneTexture()
  sideMap.repeat.set((FRONT - BACK) / 4, wallHeight / 4)
  const sideMaterial = new THREE.MeshStandardMaterial({ map: sideMap, bumpMap: sideMap, bumpScale: 0.04, roughness: 0.9 })
  const endMap = sideMap.clone()
  endMap.repeat.set((HALF_WIDTH * 2) / 4, wallHeight / 4)
  const endMaterial = new THREE.MeshStandardMaterial({ map: endMap, bumpMap: endMap, bumpScale: 0.04, roughness: 0.9 })
  for (const side of [-1, 1]) {
    const wall = box(0.6, wallHeight, FRONT - BACK, sideMaterial, side * (HALF_WIDTH + 0.3), FLOOR + wallHeight / 2, (FRONT + BACK) / 2)
    wall.castShadow = false
    group.add(wall)
  }
  for (const z of [BACK - 0.3, FRONT + 0.3]) {
    const wall = box(HALF_WIDTH * 2 + 1.2, wallHeight, 0.6, endMaterial, 0, FLOOR + wallHeight / 2, z)
    wall.castShadow = false
    group.add(wall)
  }

  const glass = new THREE.MeshBasicMaterial({ map: leadedGlassTexture(), fog: false })
  const sill = new THREE.MeshStandardMaterial({ color: 0xcdb791, roughness: 0.85 })
  const pilasterMap = sideMap.clone()
  pilasterMap.repeat.set(0.2, wallHeight / 4)
  const pilaster = new THREE.MeshStandardMaterial({ map: pilasterMap, bumpMap: pilasterMap, bumpScale: 0.04, roughness: 0.88 })
  const patchMaterial = new THREE.MeshBasicMaterial({ map: lightPatchTexture(), color: 0xffe2b0, transparent: true, opacity: 0.42, depthWrite: false, blending: THREE.AdditiveBlending, fog: false })
  const shaftMaterial = new THREE.MeshBasicMaterial({ map: shaftTexture(), color: 0xffe9c4, transparent: true, opacity: 0.16, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide, fog: false })
  const windowGeometry = lancet(1.9, 5.6)
  const windowBottom = 1.2
  const banners: Array<THREE.Group> = []
  let bannerIndex = 0
  for (let z = BACK + BAY; z < FRONT; z += BAY) {
    for (const side of [-1, 1]) {
      const pane = new THREE.Mesh(windowGeometry, glass)
      pane.position.set(side * (HALF_WIDTH - 0.02), windowBottom, z)
      pane.rotation.y = -side * Math.PI / 2
      group.add(pane)
      group.add(box(0.5, 0.14, 2.3, sill, side * (HALF_WIDTH - 0.24), windowBottom - 0.07, z))
      const plant = fern()
      plant.position.set(side * (HALF_WIDTH - 0.3), windowBottom, z + 0.55)
      if ((z / BAY + side) % 2 === 0) group.add(plant)
      group.add(box(0.5, wallHeight, 0.7, pilaster, side * (HALF_WIDTH - 0.2), FLOOR + wallHeight / 2, z - BAY / 2))
      const flag = banner(BANNERS[bannerIndex++ % BANNERS.length] ?? 0x7a1f2b)
      flag.position.set(side * (HALF_WIDTH - 0.65), WALL_TOP - 1.1, z - BAY / 2)
      flag.rotation.y = side * Math.PI / 2
      group.add(flag)
      banners.push(flag)
      if (side === -1) {
        const center = new THREE.Vector3(-HALF_WIDTH, windowBottom + 2.6, z)
        const reach = (center.y - FLOOR) / -sunDirection.y
        const landing = center.clone().addScaledVector(sunDirection, reach)
        const patch = new THREE.Mesh(new THREE.PlaneGeometry(2.1, 3.4), patchMaterial)
        patch.rotation.x = -Math.PI / 2
        patch.rotation.z = Math.atan2(sunDirection.z, sunDirection.x) + Math.PI / 2
        patch.position.set(landing.x, FLOOR + 0.01, landing.z)
        group.add(patch)
        const shaftLength = reach * 0.95
        for (const turn of [0, Math.PI / 2]) {
          const shaft = new THREE.Mesh(new THREE.PlaneGeometry(1.9, shaftLength), shaftMaterial)
          shaft.position.copy(center).addScaledVector(sunDirection, shaftLength / 2)
          shaft.quaternion.setFromUnitVectors(new THREE.Vector3(0, -1, 0), sunDirection)
          shaft.rotateY(turn)
          group.add(shaft)
        }
      }
    }
  }
  for (const [z, facing] of [[BACK + 0.02, 0], [FRONT - 0.02, Math.PI]] as const) {
    const great = new THREE.Mesh(lancet(4.6, 7.4), glass)
    great.position.set(0, 0.2, z)
    great.rotation.y = facing
    group.add(great)
  }

  const oakMap = woodTexture(OAK)
  oakMap.repeat.set(0.4, 3)
  const oak = new THREE.MeshStandardMaterial({ map: oakMap, bumpMap: oakMap, bumpScale: 0.01, roughness: 0.62 })
  const tableTop = FLOOR + 0.78
  const tableLength = 9
  for (const x of [-6.6, 6.6]) {
    for (const zCenter of [-11.5, 4.5]) {
      group.add(box(1.15, 0.1, tableLength, oak, x, tableTop, zCenter))
      for (const offset of [-tableLength / 2 + 0.6, 0, tableLength / 2 - 0.6]) group.add(box(0.12, 0.74, 0.7, oak, x, FLOOR + 0.37, zCenter + offset))
      for (const benchSide of [-1, 1]) {
        const bx = x + benchSide * 0.95
        group.add(box(0.36, 0.07, tableLength, oak, bx, FLOOR + 0.45, zCenter))
        for (const offset of [-tableLength / 2 + 0.5, tableLength / 2 - 0.5]) group.add(box(0.3, 0.42, 0.08, oak, bx, FLOOR + 0.21, zCenter + offset))
      }
      for (const offset of [-3, 0, 3]) {
        const stand = candle(0.35)
        stand.group.position.set(x, tableTop + 0.05, zCenter + offset)
        group.add(stand.group)
      }
    }
  }

  const beamMap = woodTexture({ ...OAK, dark: 0x1f130b, light: 0x4a3120 })
  beamMap.repeat.set(0.3, 2)
  const beam = new THREE.MeshStandardMaterial({ map: beamMap, roughness: 0.75 })
  const rafterLength = Math.hypot(HALF_WIDTH, RIDGE - WALL_TOP)
  const pitch = Math.atan2(RIDGE - WALL_TOP, HALF_WIDTH)
  for (const side of [-1, 1]) {
    const roofGeometry = new THREE.PlaneGeometry(rafterLength, FRONT - BACK)
    roofGeometry.rotateX(Math.PI / 2)
    const roof = new THREE.Mesh(roofGeometry, new THREE.MeshStandardMaterial({ map: beamMap, roughness: 0.8, side: THREE.DoubleSide }))
    roof.rotation.z = -side * pitch
    roof.position.set(side * HALF_WIDTH / 2, (WALL_TOP + RIDGE) / 2 + 0.2, (FRONT + BACK) / 2)
    group.add(roof)
    for (const height of [0.3, 0.62]) group.add(box(0.22, 0.26, FRONT - BACK, beam, side * HALF_WIDTH * (1 - height), WALL_TOP + (RIDGE - WALL_TOP) * height - 0.1, (FRONT + BACK) / 2))
  }
  group.add(box(0.3, 0.3, FRONT - BACK, beam, 0, RIDGE - 0.1, (FRONT + BACK) / 2))
  const arch = new THREE.TorusGeometry(HALF_WIDTH - 0.6, 0.16, 8, 40, Math.PI)
  for (let z = BACK + BAY / 2; z < FRONT; z += BAY) {
    for (const side of [-1, 1]) {
      const rafter = box(rafterLength, 0.32, 0.24, beam, side * HALF_WIDTH / 2, (WALL_TOP + RIDGE) / 2, z)
      rafter.rotation.z = -side * pitch
      group.add(rafter)
      group.add(box(1.8, 0.34, 0.3, beam, side * (HALF_WIDTH - 0.9), WALL_TOP - 1.4, z))
    }
    group.add(box(HALF_WIDTH * 0.74, 0.3, 0.26, beam, 0, WALL_TOP + 3.2, z))
    const brace = new THREE.Mesh(arch, beam)
    brace.position.set(0, WALL_TOP - 1.4, z)
    brace.scale.y = 0.48
    group.add(brace)
  }

  const candles: Array<{ group: THREE.Group; flame: THREE.Mesh; base: THREE.Vector3; phase: number }> = []
  for (let index = 0; index < 34; index++) {
    const side = index % 2 === 0 ? -1 : 1
    const base = new THREE.Vector3(side * (5.6 + random() * 3.4), 5.2 + random() * 2.6, BACK + 1 + random() * (FRONT - BACK - 2))
    const item = candle(0.3 + random() * 0.3)
    item.group.position.copy(base)
    group.add(item.group)
    candles.push({ ...item, base, phase: random() * Math.PI * 2 })
  }

  const motes = new THREE.BufferGeometry()
  const positions = new Float32Array(700 * 3)
  for (let index = 0; index < 700; index++) {
    positions[index * 3] = -HALF_WIDTH + random() * 11
    positions[index * 3 + 1] = FLOOR + random() * 9
    positions[index * 3 + 2] = BACK + random() * (FRONT - BACK)
  }
  motes.setAttribute("position", new THREE.BufferAttribute(positions, 3))
  const dust = new THREE.Points(motes, new THREE.PointsMaterial({ map: glowTexture(), color: 0xfff1d0, size: 0.05, transparent: true, opacity: 0.55, depthWrite: false, blending: THREE.AdditiveBlending }))
  group.add(dust)

  scene.add(group)
  return {
    group,
    update(time) {
      for (const item of candles) {
        item.group.position.y = item.base.y + Math.sin(time * 0.6 + item.phase) * 0.12
        item.flame.scale.y = 1.9 + Math.sin(time * 11 + item.phase) * 0.25
      }
      for (const [index, flag] of banners.entries()) flag.children[0]?.rotation.set(Math.sin(time * 0.7 + index) * 0.03, 0, Math.sin(time * 0.5 + index * 1.7) * 0.015)
      dust.position.y = Math.sin(time * 0.15) * 0.2
      dust.rotation.y = Math.sin(time * 0.05) * 0.02
    }
  }
}
