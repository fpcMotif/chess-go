import * as THREE from "three"

const CANDLE = 0xffb95f
const FLAME = 0xffd27a
const STONE = 0x2a2c38

export interface Hall {
  readonly group: THREE.Group
  update(time: number): void
}

const candle = (height: number): THREE.Group => {
  const group = new THREE.Group()
  const wax = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.055, height, 8), new THREE.MeshStandardMaterial({ color: 0xf3ead3, roughness: 0.8 }))
  wax.position.y = height / 2
  const flame = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 8), new THREE.MeshBasicMaterial({ color: FLAME, fog: false }))
  flame.scale.set(1, 1.8, 1)
  flame.position.y = height + 0.06
  const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTexture(), color: CANDLE, transparent: true, opacity: 0.7, depthWrite: false, blending: THREE.AdditiveBlending, fog: false }))
  halo.scale.setScalar(1.4)
  halo.position.y = height + 0.08
  group.add(wax, flame, halo)
  return group
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

export const makeHall = (scene: THREE.Scene): Hall => {
  const group = new THREE.Group()
  scene.fog = new THREE.FogExp2(0x0d0e14, 0.028)

  const floor = new THREE.Mesh(new THREE.PlaneGeometry(60, 60), new THREE.MeshStandardMaterial({ color: 0x1b1c25, roughness: 0.9 }))
  floor.rotation.x = -Math.PI / 2
  floor.position.y = -3.2
  floor.receiveShadow = true
  group.add(floor)

  const pillarGeometry = new THREE.CylinderGeometry(0.55, 0.65, 14, 10)
  const pillarMaterial = new THREE.MeshStandardMaterial({ color: STONE, roughness: 0.85 })
  for (const [x, z] of [[-9, -9], [9, -9], [-9, 9], [9, 9], [-9, 0], [9, 0], [0, -11], [-5, -11], [5, -11]] as const) {
    const pillar = new THREE.Mesh(pillarGeometry, pillarMaterial)
    pillar.position.set(x, 3.8, z)
    group.add(pillar)
  }

  const window = new THREE.Mesh(new THREE.PlaneGeometry(4, 7), new THREE.MeshBasicMaterial({ color: 0x2b3f6b, transparent: true, opacity: 0.55 }))
  window.position.set(0, 4.5, -12)
  group.add(window)
  const windowGlow = new THREE.PointLight(0x5a7ad8, 25, 30, 1.6)
  windowGlow.position.set(0, 4, -9)
  group.add(windowGlow)

  const candles: Array<{ group: THREE.Group; base: THREE.Vector3; phase: number; light: THREE.PointLight | null }> = []
  let seed = 7
  const random = (): number => {
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
  }
  for (let index = 0; index < 64; index++) {
    const angle = random() * Math.PI * 2
    const radius = 6.4 + random() * 4.5
    const base = new THREE.Vector3(Math.cos(angle) * radius, 0.8 + random() * 5.5, Math.sin(angle) * radius)
    const item = candle(0.3 + random() * 0.4)
    item.position.copy(base)
    const light = index % 6 === 0 ? new THREE.PointLight(CANDLE, 6, 14, 1.8) : null
    if (light !== null) {
      light.position.y = 0.5
      item.add(light)
    }
    group.add(item)
    candles.push({ group: item, base, phase: random() * Math.PI * 2, light })
  }

  const motes = new THREE.BufferGeometry()
  const positions = new Float32Array(400 * 3)
  for (let index = 0; index < 400; index++) {
    positions[index * 3] = (random() - 0.5) * 16
    positions[index * 3 + 1] = random() * 7 - 1
    positions[index * 3 + 2] = (random() - 0.5) * 16
  }
  motes.setAttribute("position", new THREE.BufferAttribute(positions, 3))
  const dust = new THREE.Points(motes, new THREE.PointsMaterial({ color: 0xffd9a0, size: 0.04, transparent: true, opacity: 0.6, depthWrite: false }))
  group.add(dust)

  scene.add(group)
  return {
    group,
    update(time) {
      for (const item of candles) {
        item.group.position.y = item.base.y + Math.sin(time * 0.6 + item.phase) * 0.15
        if (item.light !== null) item.light.intensity = 5 + Math.sin(time * 9 + item.phase) * 0.8 + Math.sin(time * 23 + item.phase * 3) * 0.4
      }
      dust.rotation.y = time * 0.01
    }
  }
}
