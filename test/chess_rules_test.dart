import 'package:chess_go/games/chess/chess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('perft', () {
    // Reference counts: https://www.chessprogramming.org/Perft_Results
    final cases = <String, List<int>>{
      startFen: [20, 400, 8902, 197281],
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1': [
        48,
        2039,
        97862,
      ],
      '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1': [14, 191, 2812, 43238],
      'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1': [
        6,
        264,
        9467,
      ],
      'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8': [
        44,
        1486,
        62379,
      ],
    };
    cases.forEach((fen, counts) {
      test(fen, () {
        final pos = Position.fromFen(fen);
        for (var d = 0; d < counts.length; d++) {
          expect(pos.perft(d + 1), counts[d], reason: 'depth ${d + 1}');
        }
      });
    });
  });

  test('FEN round trip', () {
    for (final fen in [
      startFen,
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
    ]) {
      expect(Position.fromFen(fen).fen, fen);
    }
  });

  test('fool\'s mate is checkmate, black wins', () {
    final g = ChessGame();
    for (final s in ['f3', 'e5', 'g4', 'Qh4']) {
      g.playSan(s);
    }
    expect(g.sanHistory.last, 'Qh4#');
    expect(g.outcome, Outcome.checkmate);
    expect(g.winner, Side.black);
  });

  test('stalemate', () {
    final p = Position.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    expect(p.isStalemate, isTrue);
    expect(p.isCheckmate, isFalse);
  });

  test('castling both sides, rights lost after king move', () {
    final p = Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    final e1 = parseSquare('e1');
    final targets = p.movesFrom(e1).map((m) => squareName(m.to)).toSet();
    expect(targets, containsAll(['g1', 'c1']));
    final after = p.play(Move(e1, parseSquare('g1')));
    expect(after[parseSquare('f1')], const Piece(Side.white, Role.rook));
    expect(after.fen.split(' ')[2], 'kq');
    expect(p.san(Move(e1, parseSquare('c1'))), 'O-O-O');
  });

  test('cannot castle through check', () {
    final p = Position.fromFen('4k3/8/8/8/8/8/5r2/R3K2R w KQ - 0 1');
    final targets = p
        .movesFrom(parseSquare('e1'))
        .map((m) => squareName(m.to))
        .toSet();
    expect(targets.contains('g1'), isFalse);
    expect(targets.contains('c1'), isTrue);
  });

  test('en passant', () {
    final g = ChessGame(
      Position.fromFen(
        'rnbqkbnr/ppp1pppp/8/4P3/3p4/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      ),
    );
    g.playSan('f5');
    expect(g.position.epSquare, parseSquare('f6'));
    g.playSan('exf6');
    expect(g.position[parseSquare('f5')], isNull);
    expect(g.position[parseSquare('f6')], const Piece(Side.white, Role.pawn));
  });

  test('promotion and SAN', () {
    final p = Position.fromFen('8/P6k/8/8/8/8/8/K7 w - - 0 1');
    final promos = p.movesFrom(parseSquare('a7'));
    expect(promos.length, 4);
    expect(p.san(Move.fromUci('a7a8q')), 'a8=Q');
  });

  test('SAN disambiguation', () {
    final p = Position.fromFen('4k3/8/8/8/8/K7/8/R6R w - - 0 1');
    expect(p.san(Move.fromUci('a1d1')), 'Rad1');
    final q = Position.fromFen('4k3/8/8/R7/8/8/8/R3K3 w - - 0 1');
    expect(q.san(Move.fromUci('a1a3')), 'R1a3');
  });

  test('pinned piece cannot move', () {
    final p = Position.fromFen('4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1');
    expect(p.movesFrom(parseSquare('e2')), isEmpty);
  });

  test('insufficient material', () {
    expect(
      Position.fromFen('8/8/4k3/8/8/2K5/8/8 w - - 0 1').isInsufficientMaterial,
      isTrue,
    );
    expect(
      Position.fromFen('8/8/4k3/8/8/2KN4/8/8 w - - 0 1').isInsufficientMaterial,
      isTrue,
    );
    expect(
      Position.fromFen('8/8/4k3/8/8/2KR4/8/8 w - - 0 1').isInsufficientMaterial,
      isFalse,
    );
  });

  test('threefold repetition and undo', () {
    final g = ChessGame();
    for (var i = 0; i < 2; i++) {
      for (final s in ['Nf3', 'Nf6', 'Ng1', 'Ng8']) {
        g.playSan(s);
      }
    }
    expect(g.outcome, Outcome.threefold);
    expect(g.undo(), isTrue);
    expect(g.outcome, isNull);
  });

  test('illegal move throws', () {
    expect(
      () => Position.initial().play(Move.fromUci('e2e5')),
      throwsArgumentError,
    );
  });
}
