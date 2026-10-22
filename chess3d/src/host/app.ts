import gsap from "gsap"
import { Board, MoveIntent, makeSimulation, update } from "../simulation.ts"
import type { Promotion, Square } from "../sim/rules.ts"
import type { BoardView } from "../sim/view.ts"
import { loadCharacters } from "./characters.ts"
import { makePieceLayer } from "./pieces.ts"
import { makeScene } from "./scene.ts"

const PROMOTIONS: ReadonlyArray<{ readonly piece: Promotion; readonly label: string }> = [
  { piece: "q", label: "Queen" },
  { piece: "r", label: "Rook" },
  { piece: "b", label: "Bishop" },
  { piece: "n", label: "Knight" }
]

const NAMES = { p: "pawn", n: "knight", b: "bishop", r: "rook", q: "queen", k: "king" } as const

const describe = (view: BoardView): string => {
  const side = view.turn === "w" ? "White" : "Black"
  const last = view.lastMove
  const smash = last === null || last.capturedAt === null ? "" : `${last.color === "w" ? "White" : "Black"}'s ${NAMES[last.promotion ?? view.pieces.find((piece) => piece.square === last.to)?.kind ?? "p"]} smashes the piece on ${last.capturedAt}! `
  switch (view.outcome.kind) {
    case "checkmate":
      return `${smash}Checkmate. ${view.outcome.winner === "w" ? "White" : "Black"} wins.`
    case "draw":
      return `${smash}Draw by ${view.outcome.reason}.`
    case "playing":
      return `${smash}${side} to move${view.outcome.check ? " (check!)" : ""}.`
  }
}

const element = <T extends HTMLElement>(id: string, kind: new () => T): T => {
  const found = document.getElementById(id)
  if (!(found instanceof kind)) throw new Error(`Missing #${id}`)
  return found
}

export const start = async (): Promise<void> => {
  const canvas = element("board", HTMLCanvasElement)
  const status = element("status", HTMLDivElement)
  const moves = element("moves", HTMLOListElement)
  const promotion = element("promotion", HTMLDivElement)
  const reset = element("reset", HTMLButtonElement)

  status.textContent = "Summoning the pieces…"
  const scene = makeScene(canvas)
  await loadCharacters()
  const pieces = makePieceLayer(scene)
  let runtime = makeSimulation()
  let view = runtime.inspect(Board)
  let selected: Square | null = null
  let busy = false

  const paint = (): void => {
    const legal = view.legal.filter((move) => move.from === selected)
    const occupied = new Set(view.pieces.map((piece) => piece.square))
    scene.highlight({
      selected,
      legal: legal.map((move) => move.to),
      captures: legal.filter((move) => occupied.has(move.to) || (view.pieces.find((piece) => piece.square === move.from)?.kind === "p" && move.from.charAt(0) !== move.to.charAt(0))).map((move) => move.to),
      last: view.lastMove === null ? [] : [view.lastMove.from, view.lastMove.to]
    })
    status.textContent = describe(view)
    moves.replaceChildren(
      ...Array.from({ length: Math.ceil(view.history.length / 2) }, (_, index) => {
        const item = document.createElement("li")
        item.textContent = `${view.history[index * 2] ?? ""} ${view.history[index * 2 + 1] ?? ""}`
        return item
      })
    )
    moves.scrollTop = moves.scrollHeight
  }

  const refresh = async (): Promise<void> => {
    view = runtime.inspect(Board)
    paint()
    busy = true
    await pieces.sync(view)
    busy = false
    if (view.outcome.kind !== "playing") gsap.fromTo(status, { scale: 1 }, { scale: 1.15, yoyo: true, repeat: 1, duration: 0.25 })
  }

  const send = (from: Square, to: Square, promote: Promotion | null): void => {
    runtime.send(MoveIntent, { from, to, promotion: promote })
    const ticked = runtime.tick(update)
    if (!ticked.ok) {
      status.textContent = `Simulation failed: ${JSON.stringify(ticked.error)}`
      return
    }
    selected = null
    pieces.lift(null)
    void refresh()
  }

  const choosePromotion = (from: Square, to: Square): void => {
    promotion.replaceChildren(
      ...PROMOTIONS.map((option) => {
        const button = document.createElement("button")
        button.textContent = option.label
        button.addEventListener("click", () => {
          promotion.hidden = true
          send(from, to, option.piece)
        })
        return button
      })
    )
    promotion.hidden = false
  }

  canvas.addEventListener("pointerdown", (event) => {
    if (busy || !promotion.hidden || view.outcome.kind !== "playing") return
    const square = scene.pick(event.clientX, event.clientY)
    if (square === null) return
    const own = view.pieces.find((piece) => piece.square === square && piece.color === view.turn)
    if (selected !== null) {
      const choices = view.legal.filter((move) => move.from === selected && move.to === square)
      if (choices.length === 1 && choices[0] !== undefined) {
        send(selected, square, choices[0].promotion)
        return
      }
      if (choices.length > 1) {
        choosePromotion(selected, square)
        return
      }
    }
    selected = own === undefined || own.square === selected ? null : own.square
    pieces.lift(own === undefined || own.square !== selected ? null : own.id)
    paint()
  })

  reset.addEventListener("click", () => {
    runtime = makeSimulation()
    selected = null
    promotion.hidden = true
    void refresh()
  })

  window.addEventListener("resize", () => scene.resize())
  void refresh()
  const frame = (): void => {
    scene.render()
    requestAnimationFrame(frame)
  }
  frame()
}
