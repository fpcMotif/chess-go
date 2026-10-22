import * as THREE from "three"
import gsap from "gsap"
import type { Scene } from "./scene.ts"
import { squarePosition } from "./scene.ts"
import { makeEffects } from "./effects.ts"
import { disposeCharacter, igniteCharacter } from "./characters.ts"
import type { BoardView, PieceView } from "../sim/view.ts"
import type { Square } from "../sim/rules.ts"

const GOLD = 0xffd166
const VIOLET = 0xb48cff
const CRIMSON = 0xef4444
const EMBER = 0xff7a1a
const UP = new THREE.Vector3(0, 1, 0)
const REST_FOV = 40
const PUNCH_FOV = 36.5
const RIPPLE_DEPTH = 0.09
const RIPPLE_REACH = 3.2
const RIPPLE_DELAY = 0.045
const TREMBLE = 0.09

export interface PieceLayer {
  sync(view: BoardView): Promise<void>
  lift(id: number | null): void
  threaten(squares: ReadonlyArray<Square>): void
}

export const makePieceLayer = (scene: Scene): PieceLayer => {
  const figures = new Map<number, { figure: THREE.Group; piece: PieceView }>()
  const group = new THREE.Group()
  scene.scene.add(group)
  const effects = makeEffects(scene.scene)
  let lifted: THREE.Group | null = null
  const warmup = scene.makePiece("b", "p")
  igniteCharacter(warmup, EMBER)
  scene.renderer.compile(warmup, scene.camera, scene.scene)
  disposeCharacter(warmup)

  const discard = (figure: THREE.Group): void => {
    group.remove(figure)
    disposeCharacter(figure)
  }

  const slide = (figure: THREE.Group, to: THREE.Vector3): gsap.core.Timeline =>
    gsap
      .timeline()
      .to(figure.position, { x: to.x, z: to.z, y: 0.05, duration: 0.5, ease: "power2.inOut" }, 0)
      .to(figure.rotation, { z: 0.08, duration: 0.12, yoyo: true, repeat: 3, ease: "sine.inOut" }, 0)

  const leap = (figure: THREE.Group, to: THREE.Vector3): gsap.core.Timeline =>
    gsap
      .timeline()
      .to(figure.position, { y: 1.3, duration: 0.25, ease: "power2.out" }, 0)
      .to(figure.rotation, { x: -0.5, duration: 0.25, ease: "power2.out" }, 0)
      .to(figure.position, { x: to.x, z: to.z, duration: 0.55, ease: "power2.inOut" }, 0)
      .to(figure.rotation, { x: 0, duration: 0.3, ease: "power2.in" }, 0.35)
      .to(figure.position, { y: 0.05, duration: 0.3, ease: "bounce.out" }, 0.35)

  const smash = (attacker: THREE.Group, isKnight: boolean, victim: THREE.Group, to: THREE.Vector3): gsap.core.Timeline => {
    const apex = isKnight ? 1.3 : 0.6
    const away = to.clone().sub(attacker.position).setY(0).normalize()
    const flung = to.clone().addScaledVector(away, 0.6).addScaledVector(UP, 0.7)
    const burn = igniteCharacter(victim, EMBER)
    const timeline = gsap.timeline()
    timeline.to(attacker.position, { y: 0.35, duration: 0.25, ease: "power2.out" }, 0)
    timeline.to(attacker.scale, { x: 1.05, y: 1.05, z: 1.05, duration: 0.25, ease: "power2.out" }, 0)
    timeline.to(attacker.position, { x: to.x, z: to.z, duration: 0.35, ease: "power2.inOut" }, 0.25)
    timeline.to(attacker.position, { y: apex, duration: 0.17, ease: "power2.out" }, 0.25)
    timeline.to(attacker.rotation, { x: -0.25, duration: 0.17, ease: "power2.out" }, 0.25)
    timeline.to(attacker.position, { y: 0.05, duration: 0.18, ease: "power2.in" }, 0.42)
    timeline.to(attacker.rotation, { x: 0, duration: 0.18, ease: "power2.in" }, 0.42)
    timeline.call(() => void effects.ringBurst(to, CRIMSON), [], 0.55)
    timeline.to(victim.scale, { x: 1.15, y: 1.15, z: 1.15, duration: 0.05, ease: "power2.out" }, 0.58)
    timeline.call(
      () => {
        effects.flash(to, GOLD)
        effects.kick(scene.camera)
      },
      [],
      0.6
    )
    timeline.call(() => void scene.shockwave(to), [], 0.6)
    timeline.call(() => ripple(to, [attacker, victim]), [], 0.6)
    timeline.to(scene.camera, { fov: PUNCH_FOV, duration: 0.06, ease: "power2.out", onUpdate: () => scene.camera.updateProjectionMatrix() }, 0.6)
    timeline.to(scene.camera, { fov: REST_FOV, duration: 0.4, ease: "power2.inOut", onUpdate: () => scene.camera.updateProjectionMatrix() }, 0.66)
    timeline.to(victim.position, { x: flung.x, y: flung.y, z: flung.z, duration: 0.4, ease: "power2.out" }, 0.6)
    timeline.to(victim.rotation, { z: -0.7, duration: 0.4, ease: "power2.out" }, 0.6)
    timeline.to(burn, { value: 1, duration: 0.4, ease: "power1.in" }, 0.62)
    timeline.to(attacker.scale, { y: 0.86, x: 1.14, z: 1.14, duration: 0.06, ease: "power2.out" }, 0.6)
    timeline.call(() => void effects.embers(to, [GOLD, CRIMSON]), [], 0.62)
    timeline.call(() => void effects.afterglow(to, GOLD), [], 0.66)
    timeline.to(attacker.scale, { x: 1, y: 1, z: 1, duration: 0.18, ease: "back.out(1.7)" }, 0.66)
    timeline.call(() => discard(victim), [], 1.02)
    return timeline
  }

  const ripple = (at: THREE.Vector3, skip: ReadonlyArray<THREE.Group>): void => {
    for (const tile of scene.squares.values()) {
      const distance = Math.hypot(tile.position.x - at.x, tile.position.z - at.z)
      const depth = RIPPLE_DEPTH * (1 - distance / RIPPLE_REACH)
      if (depth <= 0) continue
      const delay = distance * RIPPLE_DELAY
      const riders = [...figures.values()].filter((entry) => !skip.includes(entry.figure) && entry.piece.square === tile.userData["square"]).map((entry) => entry.figure.position)
      gsap.to([tile.position, ...riders], { y: `-=${depth}`, duration: 0.09, delay, ease: "power2.out", yoyo: true, repeat: 1 })
    }
  }

  let threatened: Array<THREE.Group> = []

  const vanish = (figure: THREE.Group): gsap.core.Timeline =>
    gsap.timeline().to(figure.scale, { x: 0, y: 0, z: 0, duration: 0.3, onComplete: () => discard(figure) })

  const transfigure = (figure: THREE.Group, piece: PieceView): gsap.core.Timeline =>
    gsap
      .timeline()
      .to(figure.scale, { x: 0.2, y: 1.6, z: 0.2, duration: 0.25, ease: "power2.in" })
      .call(() => {
        scene.setPieceKind(figure, piece.color, piece.kind)
        effects.sparks(figure.position, VIOLET)
      })
      .to(figure.scale, { x: 1, y: 1, z: 1, duration: 0.5, ease: "elastic.out(1, 0.45)" })

  return {
    async sync(view) {
      const alive = new Set(view.pieces.map((piece) => piece.id))
      const victims = new Map<number, { figure: THREE.Group; piece: PieceView }>()
      for (const [id, entry] of figures) if (!alive.has(id)) victims.set(id, entry)
      const animations: Array<gsap.core.Animation> = []
      for (const piece of view.pieces) {
        const current = figures.get(piece.id)
        if (current === undefined) {
          const figure = scene.makePiece(piece.color, piece.kind)
          figure.position.copy(squarePosition(piece.square)).setY(0.05)
          group.add(figure)
          figures.set(piece.id, { figure, piece })
          continue
        }
        const moved = current.piece.square !== piece.square
        if (moved) {
          const target = squarePosition(piece.square)
          const victim = [...victims].find(([, entry]) => entry.piece.square === piece.square)
          if (victim !== undefined) {
            animations.push(smash(current.figure, current.piece.kind === "n", victim[1].figure, target))
            victims.delete(victim[0])
          } else {
            animations.push(current.piece.kind === "n" ? leap(current.figure, target) : slide(current.figure, target))
          }
        }
        if (current.piece.kind !== piece.kind) {
          const change = transfigure(current.figure, piece)
          animations.push(moved ? gsap.timeline().add(change, 0.5) : change)
        }
        current.piece = piece
      }
      for (const entry of victims.values()) animations.push(vanish(entry.figure))
      for (const id of figures.keys()) if (!alive.has(id)) figures.delete(id)
      await Promise.all(animations.map((animation) => animation.then()))
    },
    lift(id) {
      if (lifted !== null) {
        gsap.killTweensOf(lifted.rotation)
        gsap.to(lifted.position, { y: 0.05, duration: 0.2 })
        gsap.to(lifted.rotation, { y: 0, z: 0, duration: 0.2 })
      }
      lifted = id === null ? null : (figures.get(id)?.figure ?? null)
      if (lifted !== null) {
        gsap.to(lifted.position, { y: 0.4, duration: 0.25, ease: "back.out(2)" })
        gsap.fromTo(lifted.rotation, { z: -0.12 }, { z: 0.12, duration: 0.5, yoyo: true, repeat: -1, ease: "sine.inOut" })
      }
    },
    threaten(squares) {
      for (const figure of threatened) {
        gsap.killTweensOf(figure.rotation)
        gsap.killTweensOf(figure.scale)
        figure.rotation.z = 0
        figure.scale.setScalar(1)
      }
      threatened = [...figures.values()].filter((entry) => squares.includes(entry.piece.square)).map((entry) => entry.figure)
      for (const figure of threatened) {
        gsap.fromTo(figure.rotation, { z: -TREMBLE }, { z: TREMBLE, duration: 0.06, yoyo: true, repeat: -1, ease: "sine.inOut" })
        gsap.to(figure.scale, { x: 0.94, y: 0.92, z: 0.94, duration: 0.25, ease: "power2.out" })
      }
    }
  }
}
