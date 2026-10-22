import gsap from "gsap"
import { Board, MoveIntent, makeSimulation, update } from "../simulation.ts"
import type { Color, Promotion, Square } from "../sim/rules.ts"
import type { BoardView } from "../sim/view.ts"
import { loadCharacters } from "./characters.ts"
import { LEVELS, makeEngine, type Engine, type Level } from "./engine.ts"
import { makePieceLayer } from "./pieces.ts"
import { makeScene } from "./scene.ts"
import { stockfishTransport } from "./stockfish.ts"

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

const SEAT_DISTANCE = 10.5
const DEMO_LEVEL: Level = "tricky"
const DEMO_MOVE_PAUSE_MS = 600
const DEMO_RESTART_MS = 5000
const DEMO_ORBIT_SPEED = 0.8

const pause = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms))

const isLevel = (value: string): value is Level => value in LEVELS

const pressOnly = (group: HTMLElement, value: string): void => {
  for (const button of group.querySelectorAll("button")) button.setAttribute("aria-pressed", String(button.dataset["value"] === value))
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
  const opponentChoice = element("opponent", HTMLDivElement)
  const sideChoice = element("side", HTMLDivElement)
  const sideField = element("side-choice", HTMLFieldSetElement)

  status.textContent = "Summoning the pieces…"
  const scene = makeScene(canvas)
  scene.controls.autoRotateSpeed = DEMO_ORBIT_SPEED
  await loadCharacters()
  const pieces = makePieceLayer(scene)
  let runtime = makeSimulation()
  let view = runtime.inspect(Board)
  let selected: Square | null = null
  let busy = false
  let opponent: Level | null = null
  let human: Color = "w"
  let engine: Engine | null = null
  let thinking = false
  let round = 0
  let demo = false

  const computerToMove = (): boolean => view.outcome.kind === "playing" && (demo || (opponent !== null && view.turn !== human))

  const paint = (): void => {
    const legal = view.legal.filter((move) => move.from === selected)
    const occupied = new Set(view.pieces.map((piece) => piece.square))
    scene.highlight({
      selected,
      legal: legal.map((move) => move.to),
      captures: legal.filter((move) => occupied.has(move.to) || (view.pieces.find((piece) => piece.square === move.from)?.kind === "p" && move.from.charAt(0) !== move.to.charAt(0))).map((move) => move.to),
      last: view.lastMove === null ? [] : [view.lastMove.from, view.lastMove.to],
      checked: view.checked
    })
    status.textContent = thinking && demo ? `Demo: Stockfish plays ${view.turn === "w" ? "White" : "Black"}…` : thinking && opponent !== null ? `Stockfish (${LEVELS[opponent].label}) is thinking…` : describe(view)
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
    if (view.outcome.kind !== "playing") {
      gsap.fromTo(status, { scale: 1 }, { scale: 1.15, yoyo: true, repeat: 1, duration: 0.25 })
      if (demo) {
        const finished = round
        setTimeout(() => {
          if (demo && finished === round) newGame()
        }, DEMO_RESTART_MS)
      }
    }
    void playComputer()
  }

  const playComputer = async (): Promise<void> => {
    const level = demo ? DEMO_LEVEL : opponent
    if (level === null || thinking || !computerToMove()) return
    const started = round
    engine ??= makeEngine(stockfishTransport())
    thinking = true
    paint()
    try {
      const move = await engine.bestMove(view.uci, level)
      if (demo) await pause(DEMO_MOVE_PAUSE_MS)
      if (started !== round) return
      thinking = false
      send(move.from, move.to, move.promotion)
    } catch (error) {
      if (started !== round) return
      thinking = false
      status.textContent = `Stockfish could not move: ${error instanceof Error ? error.message : String(error)}`
    }
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
    if (!promotion.hidden) {
      promotion.hidden = true
      selected = null
      pieces.lift(null)
      paint()
      return
    }
    if (busy || thinking || computerToMove() || view.outcome.kind !== "playing") return
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

  const seat = (color: Color): void => {
    const z = color === "w" ? SEAT_DISTANCE : -SEAT_DISTANCE
    gsap.to(scene.camera.position, { x: 0, y: 9.5, z, duration: 1.1, ease: "power2.inOut", onUpdate: () => scene.controls.update() })
  }

  const newGame = (): void => {
    round += 1
    thinking = false
    runtime = makeSimulation()
    selected = null
    promotion.hidden = true
    pieces.lift(null)
    engine?.newGame()
    void refresh()
  }

  opponentChoice.addEventListener("click", (event) => {
    const value = event.target instanceof HTMLButtonElement ? event.target.dataset["value"] : undefined
    if (value === undefined) return
    opponent = isLevel(value) ? value : null
    const leavingDemo = demo && value !== "demo"
    demo = value === "demo"
    scene.controls.autoRotate = demo
    pressOnly(opponentChoice, value)
    sideField.hidden = opponent === null
    if (!demo && opponent === null && human === "b") {
      human = "w"
      pressOnly(sideChoice, "w")
      seat("w")
    } else if (leavingDemo) {
      seat(human)
    }
    newGame()
  })

  sideChoice.addEventListener("click", (event) => {
    const value = event.target instanceof HTMLButtonElement ? event.target.dataset["value"] : undefined
    if (value !== "w" && value !== "b") return
    human = value
    pressOnly(sideChoice, value)
    seat(value)
    newGame()
  })

  reset.addEventListener("click", newGame)

  window.addEventListener("resize", () => scene.resize())
  void refresh()
  const frame = (): void => {
    scene.render()
    requestAnimationFrame(frame)
  }
  frame()
}
