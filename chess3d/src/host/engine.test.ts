import { describe, expect, test } from "bun:test"
import { LEVELS, makeEngine, parseBestMove, type Transport } from "./engine.ts"

const fakeEngine = (reply: string) => {
  const sent: Array<string> = []
  let handler: (line: string) => void = () => {}
  const transport: Transport = {
    send(line) {
      sent.push(line)
      const answer = line === "uci" ? "uciok" : line === "isready" ? "readyok" : line.startsWith("go") ? reply : null
      if (answer !== null) queueMicrotask(() => handler(answer))
    },
    listen(next) {
      handler = next
    },
    close() {}
  }
  return { transport, sent }
}

describe("engine driver", () => {
  test("parses a best move with and without promotion", () => {
    expect(parseBestMove("bestmove e2e4 ponder e7e5")).toEqual({ from: "e2", to: "e4", promotion: null })
    expect(parseBestMove("bestmove a7a8q")).toEqual({ from: "a7", to: "a8", promotion: "q" })
    expect(parseBestMove("bestmove (none)")).toBeNull()
    expect(parseBestMove("info depth 3 score cp 20")).toBeNull()
  })

  test("asks for a move at the chosen strength from the game so far", async () => {
    const { transport, sent } = fakeEngine("bestmove d8h4")
    const engine = makeEngine(transport)
    const move = await engine.bestMove(["f2f3", "e7e5", "g2g4"], "tricky")
    expect(move).toEqual({ from: "d8", to: "h4", promotion: null })
    expect(sent).toContain(`setoption name Skill Level value ${LEVELS.tricky.skill}`)
    expect(sent).toContain("position startpos moves f2f3 e7e5 g2g4")
    expect(sent.at(-1)).toBe(LEVELS.tricky.search)
  })

  test("starts from the initial position when no moves were played", async () => {
    const { transport, sent } = fakeEngine("bestmove e2e4")
    await makeEngine(transport).bestMove([], "easy")
    expect(sent).toContain("position startpos")
  })

  test("levels get stronger from easy to hard", () => {
    expect(LEVELS.easy.skill).toBeLessThan(LEVELS.tricky.skill)
    expect(LEVELS.tricky.skill).toBeLessThan(LEVELS.hard.skill)
    expect(LEVELS.hard.skill).toBe(20)
  })

  test("a position with no move rejects", async () => {
    const { transport } = fakeEngine("bestmove (none)")
    await expect(makeEngine(transport).bestMove(["f2f3", "e7e5", "g2g4", "d8h4"], "hard")).rejects.toThrow("no move")
  })
})
