import * as THREE from "three"
import sky from "../assets/astral/sky.jpg"
import { glowTexture } from "./hall.ts"
import { flagstoneTexture, limestoneTexture } from "./stone.ts"

const FLOOR = -3.2
const TOWER_RADIUS = 10.5
const SKY_RADIUS = 46
const SKY_FADE = 0.45
const SKY_HORIZON = 0.62
const HORIZON = 1
const NIGHT = 0x070818
const MOON = 0xc4d4ff
const BRASS = 0xc8963e
const STAR = 0xffd166

export interface Observatory {
  readonly group: THREE.Group
  update(time: number): void
}

const skyTexture = (image: HTMLImageElement): THREE.CanvasTexture => {
  const fade = Math.round(image.naturalHeight * SKY_FADE)
  const canvas = document.createElement("canvas")
  canvas.width = image.naturalWidth
  canvas.height = image.naturalHeight + fade
  const context = canvas.getContext("2d")
  if (context === null) throw new Error("2d canvas unavailable")
  context.fillStyle = "#070818"
  context.fillRect(0, 0, canvas.width, canvas.height)
  context.drawImage(image, 0, fade)
  const gradient = context.createLinearGradient(0, fade * 0.6, 0, fade * 1.5)
  gradient.addColorStop(0, "rgba(7,8,24,1)")
  gradient.addColorStop(1, "rgba(7,8,24,0)")
  context.fillStyle = gradient
  context.fillRect(0, 0, canvas.width, fade * 1.5)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.wrapS = THREE.MirroredRepeatWrapping
  texture.repeat.x = 2
  return texture
}

let cachedChart: THREE.CanvasTexture | null = null
export const chartTexture = (): THREE.CanvasTexture => {
  if (cachedChart !== null) return cachedChart
  const size = 256
  const canvas = document.createElement("canvas")
  canvas.width = canvas.height = size
  const context = canvas.getContext("2d")
  if (context !== null) {
    context.fillStyle = "rgb(205,210,222)"
    context.fillRect(0, 0, size, size)
    context.strokeStyle = "rgba(255,255,255,0.9)"
    context.lineWidth = 1.2
    for (const radius of [70, 110, 150]) {
      context.beginPath()
      context.arc(size * 0.3, size * 0.7, radius, 0, Math.PI * 2)
      context.stroke()
    }
    let seed = 13
    const next = (): number => {
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    }
    const stars = Array.from({ length: 7 }, () => [20 + next() * 216, 20 + next() * 216] as const)
    context.beginPath()
    for (const [index, [x, y]] of stars.entries()) {
      if (index === 0) context.moveTo(x, y)
      else context.lineTo(x, y)
    }
    context.stroke()
    context.fillStyle = "rgb(255,255,255)"
    for (const [x, y] of stars) {
      context.beginPath()
      context.arc(x, y, 3, 0, Math.PI * 2)
      context.fill()
    }
  }
  cachedChart = new THREE.CanvasTexture(canvas)
  cachedChart.colorSpace = THREE.SRGBColorSpace
  cachedChart.anisotropy = 4
  return cachedChart
}

const armillary = (): { group: THREE.Group; rings: Array<THREE.Object3D> } => {
  const brass = new THREE.MeshStandardMaterial({ color: BRASS, metalness: 1, roughness: 0.32 })
  const group = new THREE.Group()
  const rings: Array<THREE.Object3D> = []
  for (const [radius, tiltX, tiltZ] of [[1.5, Math.PI / 2, 0], [1.35, Math.PI / 2, 0.4], [1.2, 0.35, 0], [1.05, Math.PI / 2, -0.7]] as const) {
    const ring = new THREE.Mesh(new THREE.TorusGeometry(radius, 0.035, 10, 96), brass)
    ring.rotation.set(tiltX, 0, tiltZ)
    const pivot = new THREE.Group()
    pivot.add(ring)
    const planet = new THREE.Mesh(new THREE.SphereGeometry(0.09 + radius * 0.03, 16, 12), new THREE.MeshStandardMaterial({ color: [0x7fb3d5, 0xd98c5f, 0x9fd8b0, 0xe0c27a][rings.length], roughness: 0.5 }))
    planet.position.set(radius, 0, 0)
    ring.add(planet)
    group.add(pivot)
    rings.push(pivot)
  }
  const sun = new THREE.Mesh(new THREE.SphereGeometry(0.3, 24, 16), new THREE.MeshStandardMaterial({ color: 0xffb347, emissive: 0xff9a2e, emissiveIntensity: 2.2 }))
  const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTexture(), color: 0xffb347, transparent: true, opacity: 0.7, depthWrite: false, blending: THREE.AdditiveBlending }))
  glow.scale.setScalar(1.6)
  const light = new THREE.PointLight(0xffc070, 8, 10, 2)
  const axis = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 3.6, 8), brass)
  axis.rotation.z = 0.4
  const column = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.14, 2.4, 16), brass)
  column.position.y = -2.9
  const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.75, 0.2, 32), brass)
  foot.position.y = -4.1
  column.castShadow = foot.castShadow = true
  group.add(sun, glow, light, axis, column, foot)
  return { group, rings }
}

const telescope = (): THREE.Group => {
  const brass = new THREE.MeshStandardMaterial({ color: BRASS, metalness: 1, roughness: 0.28 })
  const wood = new THREE.MeshStandardMaterial({ color: 0x3b2618, roughness: 0.7 })
  const group = new THREE.Group()
  for (let index = 0; index < 3; index++) {
    const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.05, 2.2, 8), wood)
    const angle = (index * Math.PI * 2) / 3
    leg.position.set(Math.sin(angle) * 0.45, 1, Math.cos(angle) * 0.45)
    leg.rotation.set(Math.cos(angle) * 0.4, 0, -Math.sin(angle) * 0.4)
    leg.castShadow = true
    group.add(leg)
  }
  const tube = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.2, 2.6, 24), brass)
  tube.position.y = 2.25
  tube.rotation.set(-0.9, 0, 0.3)
  tube.castShadow = true
  group.add(tube)
  return group
}

export const makeObservatory = (scene: THREE.Scene): Observatory => {
  const group = new THREE.Group()

  const moon = new THREE.DirectionalLight(MOON, 1.8)
  moon.position.set(16, 18, -20)
  moon.castShadow = true
  moon.shadow.mapSize.set(2048, 2048)
  moon.shadow.camera.left = moon.shadow.camera.bottom = -12
  moon.shadow.camera.right = moon.shadow.camera.top = 12
  moon.shadow.bias = -0.0004
  group.add(moon, moon.target)
  group.add(new THREE.HemisphereLight(0x8ea2ff, 0x1a1030, 0.9))

  const dome = new THREE.Mesh(new THREE.SphereGeometry(SKY_RADIUS + 8, 48, 24), new THREE.MeshBasicMaterial({ color: NIGHT, side: THREE.BackSide, fog: false }))
  group.add(dome)
  const backdrop = new THREE.Mesh(new THREE.CylinderGeometry(SKY_RADIUS, SKY_RADIUS, 1, 128, 1, true), new THREE.MeshBasicMaterial({ color: 0xffffff, side: THREE.BackSide, fog: false, transparent: true, opacity: 0 }))
  group.add(backdrop)
  const image = new Image()
  image.onload = () => {
    const texture = skyTexture(image)
    const height = ((Math.PI * SKY_RADIUS) * texture.image.height) / texture.image.width
    backdrop.geometry.dispose()
    backdrop.geometry = new THREE.CylinderGeometry(SKY_RADIUS, SKY_RADIUS, height, 128, 1, true)
    const horizonFromBottom = (image.naturalHeight * (1 - SKY_HORIZON)) / texture.image.height
    backdrop.position.y = HORIZON + (0.5 - horizonFromBottom) * height
    backdrop.material.map = texture
    backdrop.material.opacity = 1
    backdrop.material.needsUpdate = true
  }
  image.src = sky

  let seed = 29
  const random = (): number => {
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
  }
  const starPositions = new Float32Array(900 * 3)
  for (let index = 0; index < 900; index++) {
    const theta = random() * Math.PI * 2
    const elevation = 0.35 + random() * 1.2
    const radius = SKY_RADIUS + 4
    starPositions[index * 3] = Math.cos(theta) * Math.cos(elevation) * radius
    starPositions[index * 3 + 1] = Math.sin(elevation) * radius
    starPositions[index * 3 + 2] = Math.sin(theta) * Math.cos(elevation) * radius
  }
  const starGeometry = new THREE.BufferGeometry()
  starGeometry.setAttribute("position", new THREE.BufferAttribute(starPositions, 3))
  const stars = new THREE.Points(starGeometry, new THREE.PointsMaterial({ map: glowTexture(), color: 0xe8e2ff, size: 0.55, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, fog: false }))
  group.add(stars)

  const floorMap = flagstoneTexture()
  floorMap.repeat.set(4, 4)
  const floor = new THREE.Mesh(new THREE.CircleGeometry(TOWER_RADIUS + 0.6, 64), new THREE.MeshStandardMaterial({ map: floorMap, bumpMap: floorMap, bumpScale: 0.03, color: 0x8a90aa, roughness: 0.85 }))
  floor.rotation.x = -Math.PI / 2
  floor.position.y = FLOOR
  floor.receiveShadow = true
  group.add(floor)

  const stoneMap = limestoneTexture()
  stoneMap.repeat.set(10, 0.6)
  const stone = new THREE.MeshStandardMaterial({ map: stoneMap, bumpMap: stoneMap, bumpScale: 0.03, color: 0x9ea4bf, roughness: 0.9 })
  const wall = new THREE.Mesh(new THREE.CylinderGeometry(TOWER_RADIUS + 0.6, TOWER_RADIUS + 0.6, 1.1, 96, 1, true), stone)
  wall.position.y = FLOOR + 0.55
  const inner = new THREE.Mesh(new THREE.CylinderGeometry(TOWER_RADIUS, TOWER_RADIUS, 1.1, 96, 1, true), new THREE.MeshStandardMaterial({ map: stoneMap, color: 0x9ea4bf, roughness: 0.9, side: THREE.BackSide }))
  inner.position.y = FLOOR + 0.55
  const cap = new THREE.Mesh(new THREE.RingGeometry(TOWER_RADIUS, TOWER_RADIUS + 0.6, 96), stone)
  cap.rotation.x = -Math.PI / 2
  cap.position.y = FLOOR + 1.1
  group.add(wall, inner, cap)
  const merlonGeometry = new THREE.BoxGeometry(1.1, 0.8, 0.6)
  for (let index = 0; index < 28; index++) {
    const angle = (index / 28) * Math.PI * 2
    const merlon = new THREE.Mesh(merlonGeometry, stone)
    merlon.position.set(Math.cos(angle) * (TOWER_RADIUS + 0.3), FLOOR + 1.5, Math.sin(angle) * (TOWER_RADIUS + 0.3))
    merlon.rotation.y = -angle + Math.PI / 2
    merlon.castShadow = true
    group.add(merlon)
  }
  const pedestal = new THREE.Mesh(new THREE.CylinderGeometry(1.4, 2, 2.6, 48), stone)
  pedestal.position.y = FLOOR + 1.3
  pedestal.receiveShadow = true
  group.add(pedestal)

  const scope = telescope()
  scope.position.set(-7.2, FLOOR, -4.5)
  scope.rotation.y = 0.6
  group.add(scope)

  const sphere = armillary()
  sphere.group.position.set(6.2, FLOOR + 4.2, -5.8)
  group.add(sphere.group)

  const moteGeometry = new THREE.BufferGeometry()
  const motes = new Float32Array(300 * 3)
  for (let index = 0; index < 300; index++) {
    motes[index * 3] = (random() - 0.5) * 18
    motes[index * 3 + 1] = FLOOR + random() * 10
    motes[index * 3 + 2] = (random() - 0.5) * 18
  }
  moteGeometry.setAttribute("position", new THREE.BufferAttribute(motes, 3))
  const dust = new THREE.Points(moteGeometry, new THREE.PointsMaterial({ map: glowTexture(), color: STAR, size: 0.07, transparent: true, opacity: 0.7, depthWrite: false, blending: THREE.AdditiveBlending }))
  group.add(dust)

  scene.add(group)
  return {
    group,
    update(time) {
      for (const [index, ring] of sphere.rings.entries()) ring.rotation.y = time * (0.12 + index * 0.07) * (index % 2 === 0 ? 1 : -1)
      stars.rotation.y = time * 0.004
      dust.position.y = Math.sin(time * 0.2) * 0.25
      dust.rotation.y = time * 0.01
    }
  }
}
