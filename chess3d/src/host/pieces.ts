import * as THREE from "three"
import gsap from "gsap"
import type { Scene } from "./scene.ts"
import { squarePosition } from "./scene.ts"
import { makeEffects } from "./effects.ts"
import { PALETTES, disposeCharacter } from "./characters.ts"
import type { BoardView, PieceView } from "../sim/view.ts"

const GOLD = 0xffd166
const VIOLET = 0xb48cff

export interface PieceLayer {
  sync(view: BoardView): Promise<void>
  lift(id: number | null): void
}

export const makePieceLayer = (scene: Scene): PieceLayer => {
  const figures = new Map<number, { figure: THREE.Group; piece: PieceView }>()
  const group = new THREE.Group()
  scene.scene.add(group)
  const effects = makeEffects(scene.scene)
  let lifted: THREE.Group | null = null

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

  const brawl = (attacker: THREE.Group, isKnight: boolean, victim: { figure: THREE.Group; piece: PieceView }, to: THREE.Vector3): gsap.core.Timeline => {
    const timeline = gsap.timeline()
    timeline.add(isKnight ? leap(attacker, to) : slide(attacker, to), 0)
    timeline.to(victim.figure.rotation, { z: 0.3, duration: 0.07, yoyo: true, repeat: 5 }, 0.1)
    timeline.to(victim.figure.position, { y: 0.25, duration: 0.2, ease: "power2.out" }, 0.3)
    timeline.to(attacker.scale, { y: 1.3, x: 0.85, z: 0.85, duration: 0.12, ease: "power2.out" }, 0.35)
    timeline.to(attacker.scale, { y: 1, x: 1, z: 1, duration: 0.35, ease: "elastic.out(1, 0.4)" }, 0.47)
    timeline.call(
      () => {
        discard(victim.figure)
        effects.shatter(to, PALETTES[victim.piece.color].robe)
        effects.sparks(to, GOLD)
        void effects.shake(scene.camera)
      },
      [],
      0.47
    )
    return timeline
  }

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
            animations.push(brawl(current.figure, current.piece.kind === "n", victim[1], target))
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
    }
  }
}
