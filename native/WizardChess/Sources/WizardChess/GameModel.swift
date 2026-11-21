import ChessCore
import Observation

struct MoveEffect: Equatable {
  let id: Int
  let move: Move
  let mover: Piece
  let victimSquare: Square?
  let victim: Piece?
  let rook: (from: Square, to: Square)?

  static func == (a: MoveEffect, b: MoveEffect) -> Bool { a.id == b.id }
}

struct PendingPromotion: Equatable {
  let from: Square
  let to: Square
  let side: Side
}

@Observable
final class GameModel {
  private(set) var game = ChessGame()
  private(set) var selected: Square?
  private(set) var effect: MoveEffect?
  private(set) var pendingPromotion: PendingPromotion?
  var flipped = false
  var saga = Saga.olympus
  private(set) var banner: (id: Int, text: String, side: Side)?
  private var effectCount = 0
  private var bannerTask: Task<Void, Never>?

  private func proclaim(_ text: String, _ side: Side) {
    effectCount += 1
    banner = (effectCount, text, side)
    bannerTask?.cancel()
    bannerTask = Task { [id = effectCount] in
      try? await Task.sleep(for: .seconds(3.2))
      if !Task.isCancelled, banner?.id == id { banner = nil }
    }
  }

  var position: Position { game.position }
  var isOver: Bool { game.outcome != nil }

  var hints: Set<Square> {
    guard let s = selected else { return [] }
    return Set(position.moves(from: s).map(\.to))
  }

  var checkSquare: Square? {
    position.isCheck ? position.kingSquare(position.turn) : nil
  }

  var matedSquare: Square? {
    game.outcome == .checkmate ? position.kingSquare(position.turn) : nil
  }

  var status: String {
    let turn = saga.army(position.turn).name
    switch game.outcome {
    case .checkmate: return "Checkmate. The \(saga.army(game.winner ?? .white).name) triumph"
    case .stalemate: return "Draw by stalemate"
    case .insufficientMaterial: return "Draw: insufficient material"
    case .fiftyMoves: return "Draw: fifty-move rule"
    case .threefold: return "Draw by threefold repetition"
    case nil: return position.isCheck ? "\(turn) to move, check" : "\(turn) to move"
    }
  }

  func tap(_ sq: Square) {
    guard !isOver, !isReplaying, pendingPromotion == nil else { return }
    if let sel = selected, sel != sq, position.moves(from: sel).contains(where: { $0.to == sq }) {
      tryMove(from: sel, to: sq)
      return
    }
    selected = (selected != sq && position[sq]?.side == position.turn) ? sq : nil
  }

  func choosePromotion(_ role: Role?) {
    guard let p = pendingPromotion else { return }
    pendingPromotion = nil
    guard let role else {
      selected = nil
      return
    }
    play(Move(p.from, p.to, promotion: role))
  }

  private(set) var isReplaying = false
  private var replay: Task<Void, Never>?

  static let operaGame = [
    "e4", "e5", "Nf3", "d6", "d4", "Bg4", "dxe5", "Bxf3", "Qxf3", "dxe5", "Bc4", "Nf6", "Qb3", "Qe7",
    "Nc3", "c6", "Bg5", "b5", "Nxb5", "cxb5", "Bxb5+", "Nbd7", "O-O-O", "Rd8", "Rxd7", "Rxd7", "Rd1",
    "Qe6", "Bxd7+", "Nxd7", "Qb8+", "Nxb8", "Rd8#",
  ]

  func replayOperaGame() {
    reset()
    isReplaying = true
    replay = Task {
      for san in Self.operaGame {
        try? await Task.sleep(for: .seconds(2.1))
        guard !Task.isCancelled, let m = try? position.parseSan(san) else { break }
        play(m)
      }
      isReplaying = false
    }
  }

  func stage(_ sans: [String]) {
    reset()
    for san in sans {
      guard let m = try? position.parseSan(san) else { return }
      _ = try? game.play(m)
    }
  }

  func playSan(_ san: String) {
    if let m = try? position.parseSan(san) { play(m) }
  }

  func undo() {
    stopReplay()
    game.undo()
    selected = nil
    effect = nil
  }

  private func stopReplay() {
    replay?.cancel()
    replay = nil
    isReplaying = false
  }

  func reset() {
    stopReplay()
    game = ChessGame()
    selected = nil
    effect = nil
    pendingPromotion = nil
  }

  private func tryMove(from: Square, to: Square) {
    let candidates = position.moves(from: from).filter { $0.to == to }
    if candidates.count > 1 {
      pendingPromotion = PendingPromotion(from: from, to: to, side: position.turn)
      return
    }
    if let m = candidates.first { play(m) }
  }

  private func play(_ m: Move) {
    let before = position
    guard let mover = before[m.from], (try? game.play(m)) != nil else { return }
    effectCount += 1
    let rook: (Square, Square)? =
      before.isCastle(m) ? (m.to > m.from ? (m.from + 3, m.from + 1) : (m.from - 4, m.from - 1)) : nil
    let victimSquare = before.capturedSquare(m)
    let victim = victimSquare.flatMap { before[$0] }
    effect = MoveEffect(
      id: effectCount, move: m, mover: mover, victimSquare: victimSquare, victim: victim, rook: rook)
    selected = nil
    let army = saga.army(mover.side)
    if game.outcome == .checkmate {
      let loser = saga.army(position.turn)
      proclaim("\(loser.hero(.king)) falls. The \(army.name) rule.", mover.side)
    } else if let victim {
      proclaim("\(army.hero(mover.role)) \(mover.role.deed) \(saga.army(victim.side).hero(victim.role))", mover.side)
    } else if position.isCheck {
      proclaim("\(saga.army(position.turn).hero(.king)) is in peril", mover.side)
    } else if m.promotion != nil {
      proclaim("A \(army.hero(.pawn)) ascends", mover.side)
    }
  }
}
