import { describe, expect, test } from "bun:test"
import { HostClock } from "@typeonce/ritmo"
import { Determinism } from "@typeonce/ritmo-devtools"
import { Board, MoveIntent, makeSimulation, setup, update } from "./simulation.ts"
import type { Promotion, Square } from "./sim/rules.ts"

const play = (moves: ReadonlyArray<readonly [Square, Square] | readonly [Square, Square, Promotion]>) => {
  const runtime = makeSimulation()
  for (const move of moves) {
    runtime.send(MoveIntent, { from: move[0], to: move[1], promotion: move[2] ?? null })
    const ticked = runtime.tick(update)
    if (!ticked.ok) throw new Error(JSON.stringify(ticked.error))
  }
  return runtime.inspect(Board)
}

const pieceAt = (view: ReturnType<typeof play>, square: Square) => view.pieces.find((piece) => piece.square === square)

describe("chess simulation", () => {
  test("starts with 32 pieces and white to move", () => {
    const view = play([])
    expect(view.pieces).toHaveLength(32)
    expect(view.turn).toBe("w")
    expect(view.legal).toHaveLength(20)
  })

  test("an illegal move changes nothing", () => {
    const view = play([["e2", "e5"]])
    expect(view.history).toEqual([])
    expect(pieceAt(view, "e2")?.kind).toBe("p")
  })

  test("a capture removes the taken piece", () => {
    const view = play([["e2", "e4"], ["d7", "d5"], ["e4", "d5"]])
    expect(view.pieces).toHaveLength(31)
    expect(pieceAt(view, "d5")).toMatchObject({ color: "w", kind: "p" })
    expect(view.history).toEqual(["e4", "d5", "exd5"])
  })

  test("en passant removes the pawn behind the landing square", () => {
    const view = play([["e2", "e4"], ["a7", "a6"], ["e4", "e5"], ["d7", "d5"], ["e5", "d6"]])
    expect(pieceAt(view, "d5")).toBeUndefined()
    expect(pieceAt(view, "d6")).toMatchObject({ color: "w", kind: "p" })
    expect(view.pieces).toHaveLength(31)
  })

  test("castling moves the rook too", () => {
    const view = play([["e2", "e4"], ["e7", "e5"], ["g1", "f3"], ["b8", "c6"], ["f1", "c4"], ["f8", "c5"], ["e1", "g1"]])
    expect(pieceAt(view, "g1")?.kind).toBe("k")
    expect(pieceAt(view, "f1")?.kind).toBe("r")
    expect(pieceAt(view, "h1")).toBeUndefined()
  })

  test("promotion changes the pawn's kind", () => {
    const view = play([["a2", "a4"], ["b7", "b5"], ["a4", "b5"], ["a7", "a6"], ["b5", "a6"], ["h7", "h6"], ["a6", "a7"], ["h6", "h5"], ["a7", "b8", "q"]])
    expect(pieceAt(view, "b8")).toMatchObject({ color: "w", kind: "q" })
    expect(view.history.at(-1)).toBe("axb8=Q")
  })

  test("fool's mate ends the game", () => {
    const view = play([["f2", "f3"], ["e7", "e5"], ["g2", "g4"], ["d8", "h4"]])
    expect(view.outcome).toEqual({ kind: "checkmate", winner: "b" })
    expect(view.legal).toHaveLength(0)
  })

  test("the simulation is deterministic", () => {
    const result = Determinism.check(({ hostClock }) => ({ runtime: makeSimulation({ hostClock }), schedules: { setup, update } }), {
      schedule: "update",
      frames: 60,
      hostClock: HostClock.test()
    })
    expect(result.ok).toBe(true)
  })
})
