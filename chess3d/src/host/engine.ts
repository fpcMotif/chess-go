import type { Promotion, Square } from "../sim/rules.ts"

export type Level = "easy" | "tricky" | "hard"

export interface Strength {
  readonly label: string
  readonly skill: number
  readonly search: string
}

export const LEVELS: Record<Level, Strength> = {
  easy: { label: "Easy", skill: 0, search: "go depth 1" },
  tricky: { label: "Tricky", skill: 8, search: "go movetime 400" },
  hard: { label: "Hard", skill: 20, search: "go movetime 1500" }
}

export interface EngineMove {
  readonly from: Square
  readonly to: Square
  readonly promotion: Promotion | null
}

export interface Transport {
  send(line: string): void
  listen(handler: (line: string) => void): void
  close(): void
}

export interface Engine {
  bestMove(moves: ReadonlyArray<string>, level: Level): Promise<EngineMove>
  newGame(): void
  close(): void
}

const BEST_MOVE = /^bestmove ([a-h][1-8])([a-h][1-8])([qrbn])?/

export const parseBestMove = (line: string): EngineMove | null => {
  const match = BEST_MOVE.exec(line)
  if (match === null) return null
  const [, from, to, promotion] = match
  return { from: from as Square, to: to as Square, promotion: (promotion ?? null) as Promotion | null }
}

export const makeEngine = (transport: Transport): Engine => {
  const waiting: Array<{ readonly prefix: string; readonly resolve: (line: string) => void }> = []
  transport.listen((line) => {
    const index = waiting.findIndex((entry) => line.startsWith(entry.prefix))
    if (index === -1) return
    const [entry] = waiting.splice(index, 1)
    entry?.resolve(line)
  })
  const ask = (line: string, prefix: string): Promise<string> =>
    new Promise((resolve) => {
      waiting.push({ prefix, resolve })
      transport.send(line)
    })
  const ready = ask("uci", "uciok").then(() => ask("isready", "readyok"))
  let queue: Promise<unknown> = ready

  const search = async (moves: ReadonlyArray<string>, level: Level): Promise<EngineMove> => {
    const strength = LEVELS[level]
    transport.send(`setoption name Skill Level value ${strength.skill}`)
    transport.send(moves.length === 0 ? "position startpos" : `position startpos moves ${moves.join(" ")}`)
    const move = parseBestMove(await ask(strength.search, "bestmove"))
    if (move === null) throw new Error("Engine found no move")
    return move
  }

  return {
    bestMove(moves, level) {
      const next = queue.then(() => search(moves, level))
      queue = next.catch(() => undefined)
      return next
    },
    newGame() {
      queue = queue.then(() => {
        transport.send("ucinewgame")
        return ask("isready", "readyok")
      })
    },
    close() {
      transport.close()
    }
  }
}
