import { At, Game, MoveIntent, Piece, Record } from "./schema.ts"
import { replayHistory, startingPieces, tryMove } from "./rules.ts"

export const SetupBoard = Game.System(
  "Chess/SetupBoard",
  {
    resources: { record: Game.System.writeResource(Record) },
    commands: Game.System.commands(Game.System.spawns(Piece, At))
  },
  ({ resources, commands }) => {
    for (const start of startingPieces()) {
      commands.spawn(Game.Command.spawn([Piece, { color: start.color, kind: start.kind }], [At, start.square]))
    }
    resources.record.set({ history: [], lastMove: null })
  }
)

export const ApplyMove = Game.System(
  "Chess/ApplyMove",
  {
    queries: {
      pieces: Game.Query({ selection: { piece: Game.Query.write(Piece), at: Game.Query.write(At) } })
    },
    resources: { record: Game.System.writeResource(Record) },
    events: { intents: Game.System.readEvent(MoveIntent) },
    commands: Game.System.commands(Game.System.despawns(Piece))
  },
  ({ queries, resources, events, commands }) => {
    for (const intent of events.intents.all()) {
      const record = resources.record.get()
      const game = replayHistory(record.history)
      const applied = tryMove(game, intent)
      if (applied === null) continue
      for (const match of queries.pieces.each()) {
        const square = match.data.at.get()
        if (square === applied.capturedAt) commands.despawn(match.entity)
        else if (square === applied.from) {
          match.data.at.set(applied.to)
          if (applied.promotion !== null) match.data.piece.update((piece) => ({ ...piece, kind: applied.promotion ?? piece.kind }))
        } else if (applied.rook !== null && square === applied.rook.from) match.data.at.set(applied.rook.to)
      }
      resources.record.set({ history: [...record.history, applied.san], lastMove: applied })
    }
  }
)

export const setup = Game.Schedule(SetupBoard, Game.Schedule.applyDeferred())
export const update = Game.Schedule(ApplyMove, Game.Schedule.applyDeferred())
