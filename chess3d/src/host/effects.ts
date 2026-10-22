import * as THREE from "three"
import gsap from "gsap"

const diskGeometry = new THREE.CircleGeometry(0.5, 40)
const ringGeometry = new THREE.RingGeometry(0.42, 0.5, 48)
const emberGeometry = new THREE.SphereGeometry(0.045, 6, 6)

const EMBER_COUNT = 12
const EMBER_DURATION = 0.85
const KICKS: ReadonlyArray<readonly [number, number, number]> = [
  [0.03, 0.06, 0.04],
  [0.06, -0.05, -0.03],
  [0.09, 0.03, 0],
  [0.12, -0.02, 0],
  [0.16, 0, 0]
]

export interface Effects {
  sparks(at: THREE.Vector3, color: number): gsap.core.Timeline
  ringBurst(at: THREE.Vector3, color: number): gsap.core.Timeline
  flash(at: THREE.Vector3, color: number): gsap.core.Timeline
  embers(at: THREE.Vector3, colors: readonly [number, number]): gsap.core.Timeline
  afterglow(at: THREE.Vector3, color: number): gsap.core.Timeline
  kick(camera: THREE.Camera): gsap.core.Timeline
}

const flat = (geometry: THREE.BufferGeometry, color: number, opacity: number, blending: THREE.Blending): THREE.Mesh<THREE.BufferGeometry, THREE.MeshBasicMaterial> => {
  const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false, blending }))
  mesh.rotation.x = -Math.PI / 2
  return mesh
}

export const makeEffects = (scene: THREE.Scene): Effects => {
  const flashLight = new THREE.PointLight(0xffffff, 0, 4, 2)
  scene.add(flashLight)
  const dispose = (mesh: THREE.Mesh<THREE.BufferGeometry, THREE.Material>): void => {
    scene.remove(mesh)
    mesh.material.dispose()
  }
  return {
    sparks(at, color) {
      const timeline = gsap.timeline()
      const material = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 1 })
      const sprites: Array<THREE.Mesh> = []
      for (let index = 0; index < 24; index++) {
        const spark = new THREE.Mesh(new THREE.SphereGeometry(0.03 + Math.random() * 0.03, 6, 6), material)
        spark.position.copy(at).setY(0.3)
        scene.add(spark)
        sprites.push(spark)
        const direction = new THREE.Vector3(Math.random() - 0.5, Math.random() * 1.5, Math.random() - 0.5).normalize().multiplyScalar(0.8 + Math.random() * 0.8)
        timeline.to(spark.position, { x: at.x + direction.x, y: 0.3 + direction.y, z: at.z + direction.z, duration: 0.5, ease: "power3.out" }, 0)
      }
      timeline.to(material, { opacity: 0, duration: 0.4, ease: "power1.in" }, 0.25)
      timeline.call(() => {
        for (const spark of sprites) scene.remove(spark)
        material.dispose()
      })
      return timeline
    },
    ringBurst(at, color) {
      const ring = flat(ringGeometry, color, 0.95, THREE.NormalBlending)
      ring.position.copy(at).setY(0.07)
      scene.add(ring)
      return gsap
        .timeline({ onComplete: () => dispose(ring) })
        .to(ring.scale, { x: 1.7, y: 1.7, z: 1.7, duration: 0.2, ease: "power2.out" }, 0)
        .to(ring.material, { opacity: 0, duration: 0.2, ease: "none" }, 0)
    },
    flash(at, color) {
      const disk = flat(diskGeometry, color, 0, THREE.AdditiveBlending)
      disk.position.copy(at).setY(0.08)
      disk.scale.setScalar(0.3)
      flashLight.color.setHex(color)
      flashLight.position.copy(at).setY(0.7)
      const light = flashLight
      scene.add(disk)
      return gsap
        .timeline({ onComplete: () => dispose(disk) })
        .to(disk.material, { opacity: 0.75, duration: 0.03, ease: "power2.out" }, 0)
        .to(disk.material, { opacity: 0, duration: 0.17, ease: "power2.out" }, 0.03)
        .to(disk.scale, { x: 1.3, y: 1.3, z: 1.3, duration: 0.2, ease: "power2.out" }, 0)
        .to(light, { intensity: 14, duration: 0.03, ease: "power2.out" }, 0)
        .to(light, { intensity: 0, duration: 0.17, ease: "power2.out" }, 0.03)
    },
    embers(at, colors) {
      const timeline = gsap.timeline()
      const embers: Array<THREE.Mesh<THREE.BufferGeometry, THREE.MeshBasicMaterial>> = []
      for (let index = 0; index < EMBER_COUNT; index++) {
        const ember = new THREE.Mesh(emberGeometry, new THREE.MeshBasicMaterial({ color: colors[index % 2], transparent: true, opacity: 1 }))
        ember.position.copy(at).setY(0.45)
        ember.scale.setScalar(1.8)
        scene.add(ember)
        embers.push(ember)
        const angle = (index / EMBER_COUNT) * Math.PI * 2 + 0.3
        const reach = 0.65 + (index % 3) * 0.22
        const start = (index % 4) * 0.02
        timeline.to(ember.position, { x: at.x + Math.cos(angle) * reach, z: at.z + Math.sin(angle) * reach * 0.7, y: 0.75 + (index % 3) * 0.1, duration: EMBER_DURATION, ease: "power2.out" }, start)
        timeline.to(ember.scale, { x: 0.2, y: 0.2, z: 0.2, duration: EMBER_DURATION, ease: "power2.out" }, start)
        timeline.to(ember.material, { opacity: 0, duration: 0.35, ease: "power2.out" }, start + 0.5)
      }
      timeline.call(() => {
        for (const ember of embers) dispose(ember)
      })
      return timeline
    },
    afterglow(at, color) {
      const pool = flat(diskGeometry, color, 0, THREE.AdditiveBlending)
      pool.position.copy(at).setY(0.065)
      pool.scale.setScalar(1.1)
      scene.add(pool)
      return gsap
        .timeline({ onComplete: () => dispose(pool) })
        .to(pool.material, { opacity: 0.55, duration: 0.08, ease: "power2.out" }, 0)
        .to(pool.material, { opacity: 0, duration: 0.92, ease: "power1.out" }, 0.08)
    },
    kick(camera) {
      const start = camera.position.clone()
      const right = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0).setY(0).normalize()
      const timeline = gsap.timeline({ onComplete: () => camera.position.copy(start) })
      for (const [time, side, up] of KICKS) {
        timeline.to(camera.position, { x: start.x + right.x * side, y: start.y + up, z: start.z + right.z * side, duration: 0.03, ease: "none" }, time)
      }
      return timeline
    }
  }
}
