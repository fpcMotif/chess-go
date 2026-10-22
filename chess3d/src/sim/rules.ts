import { Chess, type Color, type Move, type PieceSymbol, type Square } from "chess.js"

export type { Color, PieceSymbol, Square }

export type Promotion = Exclude<PieceSymbol, "p" | "k">

export type Outcome =
  | { readonly kind: "playing"; readonly check: boolean }
  | { readonly kind: "checkmate"; readonly winner: Color }
  | { readonly kind: "draw"; readonly reason: DrawReason }

export type DrawReason = "stalemate" | "insufficient material" | "threefold repetition" | "fifty-move rule"

export interface LegalMove {
  readonly from: Square
  readonly to: Square
  readonly promotion: Promotion | null
}

export interface AppliedMove {
  readonly san: string
  readonly from: Square
  readonly to: Square
  readonly color: Color
  readonly capturedAt: Square | null
  readonly rook: { readonly from: Square; readonly to: Square } | null
  readonly promotion: Promotion | null
}

const fileOf = (square: Square): string => square.charAt(0)
const rankOf = (square: Square): string => square.charAt(1)
const squareAt = (file: string, rank: string): Square => `${file}${rank}` as Square
const promotionOf = (move: { readonly promotion?: PieceSymbol | undefined }): Promotion | null =>
  move.promotion === undefined ? null : (move.promotion as Promotion)

export const replayHistory = (history: ReadonlyArray<string>): Chess => {
  const game = new Chess()
  for (const san of history) game.move(san)
  return game
}

export const tryMove = (
  game: Chess,
  intent: { readonly from: Square; readonly to: Square; readonly promotion: Promotion | null }
): AppliedMove | null => {
  let move: Move
  try {
    move = game.move({ from: intent.from, to: intent.to, promotion: intent.promotion ?? undefined })
  } catch {
    return null
  }
  const rank = rankOf(move.from)
  return {
    san: move.san,
    from: move.from,
    to: move.to,
    color: move.color,
    capturedAt: move.isEnPassant()
      ? squareAt(fileOf(move.to), rank)
      : move.isCapture()
        ? move.to
        : null,
    rook: move.isKingsideCastle()
      ? { from: squareAt("h", rank), to: squareAt("f", rank) }
      : move.isQueensideCastle()
        ? { from: squareAt("a", rank), to: squareAt("d", rank) }
        : null,
    promotion: promotionOf(move)
  }
}

export const legalMoves = (game: Chess): ReadonlyArray<LegalMove> =>
  game.moves({ verbose: true }).map((move) => ({ from: move.from, to: move.to, promotion: promotionOf(move) }))

export const outcomeOf = (game: Chess): Outcome => {
  if (game.isCheckmate()) return { kind: "checkmate", winner: game.turn() === "w" ? "b" : "w" }
  if (game.isStalemate()) return { kind: "draw", reason: "stalemate" }
  if (game.isInsufficientMaterial()) return { kind: "draw", reason: "insufficient material" }
  if (game.isThreefoldRepetition()) return { kind: "draw", reason: "threefold repetition" }
  if (game.isDrawByFiftyMoves()) return { kind: "draw", reason: "fifty-move rule" }
  return { kind: "playing", check: game.inCheck() }
}

export const startingPieces = (): ReadonlyArray<{ readonly square: Square; readonly color: Color; readonly kind: PieceSymbol }> =>
  new Chess()
    .board()
    .flat()
    .flatMap((cell) => (cell === null ? [] : [{ square: cell.square, color: cell.color, kind: cell.type }]))
