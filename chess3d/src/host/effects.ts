import * as THREE from "three"
import gsap from "gsap"

type Mesh = THREE.Mesh<THREE.BufferGeometry, THREE.MeshStandardMaterial>

const shardGeometry = new THREE.BoxGeometry(0.09, 0.09, 0.09)

export interface Effects {
  shatter(origin: THREE.Vector3, color: number): gsap.core.Timeline
  sparks(at: THREE.Vector3, color: number): gsap.core.Timeline
  shake(camera: THREE.Camera, strength?: number): gsap.core.Tween
}

export const makeEffects = (scene: THREE.Scene): Effects => ({
  shatter(origin, color) {
    const timeline = gsap.timeline()
    const shards: Array<Mesh> = []
    for (let index = 0; index < 18; index++) {
      const shard = new THREE.Mesh(shardGeometry, new THREE.MeshStandardMaterial({ color, roughness: 0.6 }))
      shard.castShadow = true
      shard.position.copy(origin).add(new THREE.Vector3((Math.random() - 0.5) * 0.3, Math.random() * 0.8, (Math.random() - 0.5) * 0.3))
      shard.rotation.set(Math.random() * 3, Math.random() * 3, Math.random() * 3)
      scene.add(shard)
      shards.push(shard)
      const angle = Math.random() * Math.PI * 2
      const reach = 0.6 + Math.random() * 1.2
      timeline.to(shard.position, { x: origin.x + Math.cos(angle) * reach, z: origin.z + Math.sin(angle) * reach, duration: 0.7, ease: "power2.out" }, 0)
      timeline.to(shard.position, { y: 1.2 + Math.random(), duration: 0.3, ease: "power2.out" }, 0)
      timeline.to(shard.position, { y: 0.05, duration: 0.45, ease: "bounce.out" }, 0.3)
      timeline.to(shard.rotation, { x: `+=${Math.random() * 6}`, z: `+=${Math.random() * 6}`, duration: 0.75 }, 0)
      timeline.to(shard.scale, { x: 0, y: 0, z: 0, duration: 0.3, ease: "power1.in" }, 1.1)
    }
    timeline.call(() => {
      for (const shard of shards) {
        scene.remove(shard)
        shard.material.dispose()
      }
    })
    return timeline
  },
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
  shake(camera, strength = 0.12) {
    const start = camera.position.clone()
    const offset = { t: 0 }
    return gsap.to(offset, {
      t: 1,
      duration: 0.4,
      ease: "power2.out",
      onUpdate() {
        const decay = (1 - offset.t) * strength
        camera.position.set(start.x + (Math.random() - 0.5) * decay, start.y + (Math.random() - 0.5) * decay, start.z + (Math.random() - 0.5) * decay)
      },
      onComplete() {
        camera.position.copy(start)
      }
    })
  }
})
