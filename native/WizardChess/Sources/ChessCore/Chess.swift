public enum Side: Sendable, Hashable {
  case white, black

  public var opposite: Side { self == .white ? .black : .white }
}

public enum Role: Character, Sendable, Hashable, CaseIterable {
  case pawn = "p", knight = "n", bishop = "b", rook = "r", queen = "q", king = "k"

  public init?(letter: Character) {
    guard let lower = letter.lowercased().first else { return nil }
    self.init(rawValue: lower)
  }
}

public struct Piece: Sendable, Hashable {
  public let side: Side
  public let role: Role

  public init(_ side: Side, _ role: Role) {
    self.side = side
    self.role = role
  }

  public var fenChar: Character {
    side == .white ? Character(role.rawValue.uppercased()) : role.rawValue
  }
}

public typealias Square = Int

public func fileOf(_ sq: Square) -> Int { sq & 7 }
public func rankOf(_ sq: Square) -> Int { sq >> 3 }
public func squareAt(_ file: Int, _ rank: Int) -> Square { rank * 8 + file }

public func squareName(_ sq: Square) -> String {
  let file = Character(UnicodeScalar(UInt8(97 + fileOf(sq))))
  return "\(file)\(rankOf(sq) + 1)"
}

public enum ChessError: Error, Equatable {
  case badSquare(String)
  case badFen(String)
  case illegalMove(String)
  case illegalSan(String)
}

public func parseSquare(_ s: String) throws(ChessError) -> Square {
  let bytes = Array(s.utf8)
  guard bytes.count == 2 else { throw .badSquare(s) }
  let f = Int(bytes[0]) - 97
  let r = Int(bytes[1]) - 49
  guard (0..<8).contains(f), (0..<8).contains(r) else { throw .badSquare(s) }
  return squareAt(f, r)
}

public struct Move: Sendable, Hashable, CustomStringConvertible {
  public let from: Square
  public let to: Square
  public let promotion: Role?

  public init(_ from: Square, _ to: Square, promotion: Role? = nil) {
    self.from = from
    self.to = to
    self.promotion = promotion
  }

  public var uci: String {
    squareName(from) + squareName(to) + (promotion.map { String($0.rawValue) } ?? "")
  }

  public init(uci s: String) throws(ChessError) {
    let chars = Array(s)
    guard chars.count == 4 || chars.count == 5 else { throw .badSquare(s) }
    let promo: Role? = chars.count == 5 ? Role(letter: chars[4]) : nil
    self.init(
      try parseSquare(String(chars[0...1])),
      try parseSquare(String(chars[2...3])),
      promotion: promo)
  }

  public var description: String { uci }
}

private let knightSteps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
private let kingSteps = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
private let rookDirs = [(1, 0), (0, 1), (-1, 0), (0, -1)]
private let bishopDirs = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
private let promotionRoles: [Role] = [.queen, .rook, .bishop, .knight]

public let startFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

public struct Castling: OptionSet, Sendable, Hashable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }

  public static let whiteKing = Castling(rawValue: 1)
  public static let whiteQueen = Castling(rawValue: 2)
  public static let blackKing = Castling(rawValue: 4)
  public static let blackQueen = Castling(rawValue: 8)
}

public struct Position: Sendable, Hashable {
  public private(set) var board: [Piece?]
  public private(set) var turn: Side
  public private(set) var castling: Castling
  public private(set) var epSquare: Square?
  public private(set) var halfmoves: Int
  public private(set) var fullmoves: Int

  public static var initial: Position { try! Position(fen: startFen) }

  public init(fen: String) throws(ChessError) {
    let parts = fen.split(whereSeparator: \.isWhitespace).map(String.init)
    guard parts.count >= 4 else { throw .badFen(fen) }
    var board = [Piece?](repeating: nil, count: 64)
    let rows = parts[0].split(separator: "/", omittingEmptySubsequences: false)
    guard rows.count == 8 else { throw .badFen(fen) }
    for (i, row) in rows.enumerated() {
      let rank = 7 - i
      var file = 0
      for c in row {
        if let n = c.wholeNumberValue {
          file += n
        } else {
          guard file < 8, let role = Role(letter: c) else { throw .badFen(fen) }
          board[squareAt(file, rank)] = Piece(c.isUppercase ? .white : .black, role)
          file += 1
        }
      }
      guard file == 8 else { throw .badFen(fen) }
    }
    var castling: Castling = []
    if parts[2].contains("K") { castling.insert(.whiteKing) }
    if parts[2].contains("Q") { castling.insert(.whiteQueen) }
    if parts[2].contains("k") { castling.insert(.blackKing) }
    if parts[2].contains("q") { castling.insert(.blackQueen) }
    self.board = board
    self.turn = parts[1] == "b" ? .black : .white
    self.castling = castling
    self.epSquare = parts[3] == "-" ? nil : try parseSquare(parts[3])
    self.halfmoves = parts.count > 4 ? Int(parts[4]) ?? 0 : 0
    self.fullmoves = parts.count > 5 ? Int(parts[5]) ?? 1 : 1
  }

  public var fen: String {
    var rows: [String] = []
    for rank in stride(from: 7, through: 0, by: -1) {
      var row = ""
      var empty = 0
      for file in 0..<8 {
        if let p = board[squareAt(file, rank)] {
          if empty > 0 { row += String(empty) }
          empty = 0
          row.append(p.fenChar)
        } else {
          empty += 1
        }
      }
      if empty > 0 { row += String(empty) }
      rows.append(row)
    }
    var c = ""
    if castling.contains(.whiteKing) { c += "K" }
    if castling.contains(.whiteQueen) { c += "Q" }
    if castling.contains(.blackKing) { c += "k" }
    if castling.contains(.blackQueen) { c += "q" }
    if c.isEmpty { c = "-" }
    let ep = epSquare.map(squareName) ?? "-"
    return "\(rows.joined(separator: "/")) \(turn == .white ? "w" : "b") \(c) \(ep) \(halfmoves) \(fullmoves)"
  }

  public var repetitionKey: String {
    fen.split(separator: " ").prefix(4).joined(separator: " ")
  }

  public subscript(sq: Square) -> Piece? { board[sq] }

  public func kingSquare(_ side: Side) -> Square? {
    board.firstIndex { $0 == Piece(side, .king) }
  }

  public func isAttacked(_ sq: Square, by: Side) -> Bool {
    let f = fileOf(sq), r = rankOf(sq)
    func at(_ df: Int, _ dr: Int) -> Piece? {
      let nf = f + df, nr = r + dr
      guard (0..<8).contains(nf), (0..<8).contains(nr) else { return nil }
      return board[squareAt(nf, nr)]
    }
    let pawnDr = by == .white ? -1 : 1
    let pawn = Piece(by, .pawn)
    if at(-1, pawnDr) == pawn || at(1, pawnDr) == pawn { return true }
    if knightSteps.contains(where: { at($0.0, $0.1) == Piece(by, .knight) }) { return true }
    if kingSteps.contains(where: { at($0.0, $0.1) == Piece(by, .king) }) { return true }
    func slide(_ dirs: [(Int, Int)], _ a: Role, _ b: Role) -> Bool {
      for (df, dr) in dirs {
        var nf = f + df, nr = r + dr
        while (0..<8).contains(nf), (0..<8).contains(nr) {
          if let p = board[squareAt(nf, nr)] {
            if p.side == by && (p.role == a || p.role == b) { return true }
            break
          }
          nf += df
          nr += dr
        }
      }
      return false
    }
    return slide(rookDirs, .rook, .queen) || slide(bishopDirs, .bishop, .queen)
  }

  public var isCheck: Bool { isSideInCheck(turn) }

  public func isSideInCheck(_ side: Side) -> Bool {
    guard let k = kingSquare(side) else { return false }
    return isAttacked(k, by: side.opposite)
  }

  private func pseudoLegal() -> [Move] {
    var moves: [Move] = []
    let us = turn, them = turn.opposite
    for from in 0..<64 {
      guard let p = board[from], p.side == us else { continue }
      let f = fileOf(from), r = rankOf(from)

      func addStep(_ df: Int, _ dr: Int) {
        let nf = f + df, nr = r + dr
        guard (0..<8).contains(nf), (0..<8).contains(nr) else { return }
        let to = squareAt(nf, nr)
        if board[to] == nil || board[to]?.side == them { moves.append(Move(from, to)) }
      }

      func addSlides(_ dirs: [(Int, Int)]) {
        for (df, dr) in dirs {
          var nf = f + df, nr = r + dr
          while (0..<8).contains(nf), (0..<8).contains(nr) {
            let to = squareAt(nf, nr)
            if let t = board[to] {
              if t.side == them { moves.append(Move(from, to)) }
              break
            }
            moves.append(Move(from, to))
            nf += df
            nr += dr
          }
        }
      }

      switch p.role {
      case .pawn:
        let dir = us == .white ? 1 : -1
        let startRank = us == .white ? 1 : 6
        let lastRank = us == .white ? 7 : 0
        func addPawn(_ to: Square) {
          if rankOf(to) == lastRank {
            moves += promotionRoles.map { Move(from, to, promotion: $0) }
          } else {
            moves.append(Move(from, to))
          }
        }
        let one = from + 8 * dir
        if board[one] == nil {
          addPawn(one)
          let two = from + 16 * dir
          if r == startRank && board[two] == nil { moves.append(Move(from, two)) }
        }
        for df in [-1, 1] {
          let nf = f + df
          guard (0..<8).contains(nf) else { continue }
          let to = squareAt(nf, r + dir)
          if board[to]?.side == them || to == epSquare { addPawn(to) }
        }
      case .knight:
        knightSteps.forEach { addStep($0.0, $0.1) }
      case .bishop:
        addSlides(bishopDirs)
      case .rook:
        addSlides(rookDirs)
      case .queen:
        addSlides(rookDirs)
        addSlides(bishopDirs)
      case .king:
        kingSteps.forEach { addStep($0.0, $0.1) }
        addCastles(from, &moves)
      }
    }
    return moves
  }

  private func addCastles(_ kingFrom: Square, _ moves: inout [Move]) {
    let us = turn, them = turn.opposite
    let home = us == .white ? 4 : 60
    guard kingFrom == home else { return }
    let kSide: Castling = us == .white ? .whiteKing : .blackKing
    let qSide: Castling = us == .white ? .whiteQueen : .blackQueen
    guard !castling.isDisjoint(with: [kSide, qSide]), !isAttacked(home, by: them) else { return }
    let rook = Piece(us, .rook)
    if castling.contains(kSide), board[home + 3] == rook, board[home + 1] == nil,
      board[home + 2] == nil, !isAttacked(home + 1, by: them), !isAttacked(home + 2, by: them)
    {
      moves.append(Move(home, home + 2))
    }
    if castling.contains(qSide), board[home - 4] == rook, board[home - 1] == nil,
      board[home - 2] == nil, board[home - 3] == nil, !isAttacked(home - 1, by: them),
      !isAttacked(home - 2, by: them)
    {
      moves.append(Move(home, home - 2))
    }
  }

  public var legalMoves: [Move] {
    pseudoLegal().filter { !applying($0).isSideInCheck(turn) }
  }

  public func moves(from: Square) -> [Move] {
    legalMoves.filter { $0.from == from }
  }

  public func isLegal(_ m: Move) -> Bool { legalMoves.contains(m) }

  public func isCapture(_ m: Move) -> Bool {
    board[m.to] != nil || (board[m.from]?.role == .pawn && m.to == epSquare)
  }

  public func isCastle(_ m: Move) -> Bool {
    board[m.from]?.role == .king && abs(m.to - m.from) == 2
  }

  public func capturedSquare(_ m: Move) -> Square? {
    if board[m.to] != nil { return m.to }
    if board[m.from]?.role == .pawn && m.to == epSquare {
      return m.to + (turn == .white ? -8 : 8)
    }
    return nil
  }

  public func play(_ m: Move) throws(ChessError) -> Position {
    guard isLegal(m) else { throw .illegalMove("\(m) in \(fen)") }
    return applying(m)
  }

  private func applying(_ m: Move) -> Position {
    var next = self
    guard let p = board[m.from] else { return next }
    let capture = isCapture(m)
    next.epSquare = nil
    if p.role == .pawn {
      if m.to == epSquare { next.board[m.to + (p.side == .white ? -8 : 8)] = nil }
      if abs(m.to - m.from) == 16 { next.epSquare = (m.from + m.to) / 2 }
    }
    if p.role == .king {
      if m.to - m.from == 2 {
        next.board[m.from + 1] = board[m.from + 3]
        next.board[m.from + 3] = nil
      } else if m.from - m.to == 2 {
        next.board[m.from - 1] = board[m.from - 4]
        next.board[m.from - 4] = nil
      }
      next.castling.subtract(p.side == .white ? [.whiteKing, .whiteQueen] : [.blackKing, .blackQueen])
    }
    for sq in [m.from, m.to] {
      switch sq {
      case 0: next.castling.remove(.whiteQueen)
      case 7: next.castling.remove(.whiteKing)
      case 56: next.castling.remove(.blackQueen)
      case 63: next.castling.remove(.blackKing)
      default: break
      }
    }
    next.board[m.to] = m.promotion.map { Piece(p.side, $0) } ?? p
    next.board[m.from] = nil
    next.turn = turn.opposite
    next.halfmoves = (p.role == .pawn || capture) ? 0 : halfmoves + 1
    if turn == .black { next.fullmoves += 1 }
    return next
  }

  public var isCheckmate: Bool { legalMoves.isEmpty && isCheck }
  public var isStalemate: Bool { legalMoves.isEmpty && !isCheck }

  public var isInsufficientMaterial: Bool {
    var minors: [(Role, Int)] = []
    for sq in 0..<64 {
      guard let p = board[sq], p.role != .king else { continue }
      guard p.role == .bishop || p.role == .knight else { return false }
      minors.append((p.role, (fileOf(sq) + rankOf(sq)) % 2))
    }
    if minors.count <= 1 { return true }
    return minors.allSatisfy { $0.0 == .bishop } && Set(minors.map(\.1)).count == 1
  }

  public func san(_ m: Move) -> String {
    guard let p = board[m.from] else { return m.uci }
    var s: String
    if isCastle(m) {
      s = m.to > m.from ? "O-O" : "O-O-O"
    } else if p.role == .pawn {
      s = isCapture(m) ? "\(squareName(m.from).prefix(1))x\(squareName(m.to))" : squareName(m.to)
      if let promo = m.promotion { s += "=" + promo.rawValue.uppercased() }
    } else {
      let others = legalMoves.filter { $0.to == m.to && $0.from != m.from && board[$0.from] == p }
      var dis = ""
      if !others.isEmpty {
        let name = squareName(m.from)
        if !others.contains(where: { fileOf($0.from) == fileOf(m.from) }) {
          dis = String(name.prefix(1))
        } else if !others.contains(where: { rankOf($0.from) == rankOf(m.from) }) {
          dis = String(name.suffix(1))
        } else {
          dis = name
        }
      }
      s = p.role.rawValue.uppercased() + dis + (isCapture(m) ? "x" : "") + squareName(m.to)
    }
    let next = applying(m)
    if next.isCheckmate {
      s += "#"
    } else if next.isCheck {
      s += "+"
    }
    return s
  }

  public func parseSan(_ san: String) throws(ChessError) -> Move {
    let clean = String(san.filter { !"+#!?".contains($0) }.map { $0 == "0" ? "O" : $0 })
    for m in legalMoves where self.san(m).filter({ !"+#".contains($0) }) == clean {
      return m
    }
    throw .illegalSan("\(san) in \(fen)")
  }

  public func perft(_ depth: Int) -> Int {
    if depth == 0 { return 1 }
    let moves = legalMoves
    if depth == 1 { return moves.count }
    return moves.reduce(0) { $0 + applying($1).perft(depth - 1) }
  }
}

public enum Outcome: Sendable, Hashable {
  case checkmate, stalemate, insufficientMaterial, fiftyMoves, threefold
}

public struct ChessGame: Sendable {
  public private(set) var positions: [Position]
  public private(set) var moves: [Move] = []
  public private(set) var sanHistory: [String] = []

  public init(_ start: Position = .initial) {
    positions = [start]
  }

  public var position: Position { positions[positions.count - 1] }
  public var lastMove: Move? { moves.last }

  public mutating func play(_ m: Move) throws(ChessError) {
    let next = try position.play(m)
    sanHistory.append(position.san(m))
    positions.append(next)
    moves.append(m)
  }

  public mutating func playSan(_ san: String) throws(ChessError) {
    try play(position.parseSan(san))
  }

  @discardableResult
  public mutating func undo() -> Bool {
    guard !moves.isEmpty else { return false }
    positions.removeLast()
    moves.removeLast()
    sanHistory.removeLast()
    return true
  }

  public var outcome: Outcome? {
    let p = position
    if p.isCheckmate { return .checkmate }
    if p.isStalemate { return .stalemate }
    if p.isInsufficientMaterial { return .insufficientMaterial }
    if p.halfmoves >= 100 { return .fiftyMoves }
    let key = p.repetitionKey
    if positions.filter({ $0.repetitionKey == key }).count >= 3 { return .threefold }
    return nil
  }

  public var winner: Side? { outcome == .checkmate ? position.turn.opposite : nil }
}
