import { Descriptor, Schema } from "@typeonce/ritmo"
import type { AppliedMove, Color, PieceSymbol, Promotion, Square } from "./rules.ts"

export const Piece = Descriptor.Component<{ readonly color: Color; readonly kind: PieceSymbol }>()("Chess/Piece")
export const At = Descriptor.Component<Square>()("Chess/At")

export const Record = Descriptor.Resource<{
  readonly history: ReadonlyArray<string>
  readonly lastMove: AppliedMove | null
}>()("Chess/Record")

export const MoveIntent = Descriptor.Event<{
  readonly from: Square
  readonly to: Square
  readonly promotion: Promotion | null
}>()("Chess/MoveIntent")

export const Game = Schema.bind(
  Schema.fragment({
    components: { Piece, At },
    resources: { Record },
    events: { MoveIntent }
  })
)
