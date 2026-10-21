import ChessCore
import Testing

struct PerftCase: Sendable, CustomTestStringConvertible {
  let fen: String
  let counts: [Int]
  var testDescription: String { fen }
}

@Test(arguments: [
  PerftCase(fen: startFen, counts: [20, 400, 8902]),
  PerftCase(
    fen: "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    counts: [48, 2039]),
  PerftCase(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", counts: [14, 191, 2812]),
  PerftCase(
    fen: "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", counts: [6, 264]),
  PerftCase(fen: "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", counts: [44, 1486]),
])
func perft(_ c: PerftCase) throws {
  let pos = try Position(fen: c.fen)
  for (d, n) in c.counts.enumerated() {
    #expect(pos.perft(d + 1) == n, "depth \(d + 1)")
  }
}

@Test func `FEN round trip`() throws {
  for fen in [
    startFen,
    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  ] {
    #expect(try Position(fen: fen).fen == fen)
  }
}

@Test func `fool's mate is checkmate, black wins`() throws {
  var g = ChessGame()
  for s in ["f3", "e5", "g4", "Qh4"] { try g.playSan(s) }
  #expect(g.sanHistory.last == "Qh4#")
  #expect(g.outcome == .checkmate)
  #expect(g.winner == .black)
}

@Test func stalemate() throws {
  let p = try Position(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
  #expect(p.isStalemate)
  #expect(!p.isCheckmate)
}

@Test func `castling both sides, rights lost after king move`() throws {
  let p = try Position(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
  let e1 = try parseSquare("e1")
  let targets = Set(p.moves(from: e1).map { squareName($0.to) })
  #expect(targets.isSuperset(of: ["g1", "c1"]))
  let after = try p.play(Move(e1, try parseSquare("g1")))
  #expect(after[try parseSquare("f1")] == Piece(.white, .rook))
  #expect(after.fen.split(separator: " ")[2] == "kq")
  #expect(p.san(Move(e1, try parseSquare("c1"))) == "O-O-O")
}

@Test func `cannot castle through check`() throws {
  let p = try Position(fen: "4k3/8/8/8/8/8/5r2/R3K2R w KQ - 0 1")
  let targets = Set(p.moves(from: try parseSquare("e1")).map { squareName($0.to) })
  #expect(!targets.contains("g1"))
  #expect(targets.contains("c1"))
}

@Test func `en passant`() throws {
  var g = ChessGame(try Position(fen: "rnbqkbnr/ppp1pppp/8/4P3/3p4/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"))
  try g.playSan("f5")
  #expect(g.position.epSquare == (try parseSquare("f6")))
  let capture = try g.position.parseSan("exf6")
  #expect(g.position.capturedSquare(capture) == (try parseSquare("f5")))
  try g.play(capture)
  #expect(g.position[try parseSquare("f5")] == nil)
  #expect(g.position[try parseSquare("f6")] == Piece(.white, .pawn))
}

@Test func `promotion and SAN`() throws {
  let p = try Position(fen: "8/P6k/8/8/8/8/8/K7 w - - 0 1")
  #expect(p.moves(from: try parseSquare("a7")).count == 4)
  #expect(p.san(try Move(uci: "a7a8q")) == "a8=Q")
}

@Test func `SAN disambiguation`() throws {
  let p = try Position(fen: "4k3/8/8/8/8/K7/8/R6R w - - 0 1")
  #expect(p.san(try Move(uci: "a1d1")) == "Rad1")
  let q = try Position(fen: "4k3/8/8/R7/8/8/8/R3K3 w - - 0 1")
  #expect(q.san(try Move(uci: "a1a3")) == "R1a3")
}

@Test func `pinned piece cannot move`() throws {
  let p = try Position(fen: "4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1")
  #expect(p.moves(from: try parseSquare("e2")).isEmpty)
}

@Test func `insufficient material`() throws {
  #expect(try Position(fen: "8/8/4k3/8/8/2K5/8/8 w - - 0 1").isInsufficientMaterial)
  #expect(try Position(fen: "8/8/4k3/8/8/2KN4/8/8 w - - 0 1").isInsufficientMaterial)
  #expect(try !Position(fen: "8/8/4k3/8/8/2KR4/8/8 w - - 0 1").isInsufficientMaterial)
}

@Test func `threefold repetition and undo`() throws {
  var g = ChessGame()
  for _ in 0..<2 {
    for s in ["Nf3", "Nf6", "Ng1", "Ng8"] { try g.playSan(s) }
  }
  #expect(g.outcome == .threefold)
  let undone = g.undo()
  #expect(undone)
  #expect(g.outcome == nil)
}

@Test func `illegal move throws`() throws {
  #expect(throws: ChessError.self) { try Position.initial.play(try Move(uci: "e2e5")) }
}
