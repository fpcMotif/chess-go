import { At, Game, Piece, Record } from "./schema.ts"
import { legalMoves, outcomeOf, replayHistory, type AppliedMove, type Color, type LegalMove, type Outcome, type PieceSymbol, type Square } from "./rules.ts"

export interface PieceView {
  readonly id: number
  readonly color: Color
  readonly kind: PieceSymbol
  readonly square: Square
}

export interface BoardView {
  readonly pieces: ReadonlyArray<PieceView>
  readonly turn: Color
  readonly legal: ReadonlyArray<LegalMove>
  readonly outcome: Outcome
  readonly history: ReadonlyArray<string>
  readonly lastMove: AppliedMove | null
}

export const Board = Game.Inspector(
  "Chess/Board",
  {
    queries: { pieces: Game.Query({ selection: { piece: Game.Query.read(Piece), at: Game.Query.read(At) } }) },
    resources: { record: Game.System.readResource(Record) }
  },
  ({ queries, resources }): BoardView => {
    const record = resources.record.get()
    const game = replayHistory(record.history)
    const pieces: Array<PieceView> = []
    for (const match of queries.pieces.each()) {
      const piece = match.data.piece.get()
      pieces.push({ id: match.entity.id, color: piece.color, kind: piece.kind, square: match.data.at.get() })
    }
    return {
      pieces,
      turn: game.turn(),
      legal: legalMoves(game),
      outcome: outcomeOf(game),
      history: record.history,
      lastMove: record.lastMove
    }
  }
)
