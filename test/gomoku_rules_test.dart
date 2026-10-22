import 'package:chess_go/games/gomoku/gomoku.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a position by placing stones directly. Pads with far-away
/// stones so the side to move is [turn].
GomokuGame setup(
  GomokuVariant v, {
  List<(int, int)> black = const [],
  List<(int, int)> white = const [],
  GStone turn = GStone.black,
}) {
  final g = GomokuGame(variant: v);
  void put((int, int) p, GStone s) {
    final i = g.index(p.$1, p.$2);
    g.board[i] = s;
    g.moves.add(i);
  }

  for (final p in black) {
    put(p, GStone.black);
  }
  for (final p in white) {
    put(p, GStone.white);
  }
  // Scattered padding on the edges, never in line with each other.
  const pad = [(0, 14), (3, 14), (14, 0), (14, 3), (0, 10), (10, 0)];
  var i = 0;
  while (g.turn != turn || g.moves.length.isOdd != (turn == GStone.white)) {
    put(pad[i], g.moves.length.isEven ? GStone.black : GStone.white);
    i++;
  }
  return g;
}

void main() {
  final row = [
    for (final c in [2, 3, 4, 6, 7]) (c, 7),
  ];

  group('gomoku', () {
    test('freestyle: five wins, overline wins', () {
      final g = setup(
        GomokuVariant.freestyle,
        black: row,
        white: [(0, 0), (2, 0), (4, 0), (6, 0), (8, 0)],
      );
      expect(g.play(g.index(5, 7)), isTrue);
      expect(g.winner, GStone.black);
      expect(g.winningLine.length, 6);
    });

    test('standard: overline does not win', () {
      final g = setup(
        GomokuVariant.standard,
        black: row,
        white: [(0, 0), (2, 0), (4, 0), (6, 0), (8, 0)],
      );
      expect(g.play(g.index(5, 7)), isTrue);
      expect(g.winner, isNull);
    });

    test('renju: black overline forbidden, white overline wins', () {
      final b = setup(
        GomokuVariant.renju,
        black: row,
        white: [(0, 0), (2, 0), (4, 0), (6, 0), (8, 0)],
      );
      expect(b.forbidden(b.index(5, 7)), Forbidden.overline);
      expect(b.play(b.index(5, 7)), isFalse);

      final w = setup(
        GomokuVariant.renju,
        white: row,
        black: [(0, 0), (2, 0), (4, 0), (6, 0), (8, 0), (10, 2)],
        turn: GStone.white,
      );
      expect(w.play(w.index(5, 7)), isTrue);
      expect(w.winner, GStone.white);
    });

    test('renju: double three forbidden', () {
      final g = setup(
        GomokuVariant.renju,
        black: [(5, 7), (6, 7), (7, 5), (7, 6)],
        white: [(0, 0), (2, 0), (4, 0), (6, 0)],
      );
      expect(g.forbidden(g.index(7, 7)), Forbidden.doubleThree);
    });

    test('renju: blocked three does not count', () {
      final g = setup(
        GomokuVariant.renju,
        black: [(5, 7), (6, 7), (7, 5), (7, 6)],
        white: [(4, 7), (8, 7), (0, 0), (2, 0)],
      );
      expect(g.forbidden(g.index(7, 7)), isNull);
    });

    test('renju: double four forbidden', () {
      final g = setup(
        GomokuVariant.renju,
        black: [(3, 6), (4, 6), (5, 6), (6, 3), (6, 4), (6, 5)],
        white: [(0, 0), (2, 0), (4, 0), (6, 0), (8, 0), (10, 0)],
      );
      expect(g.forbidden(g.index(6, 6)), Forbidden.doubleFour);
    });

    test('renju: four-four on one line (X.XXX.X) forbidden', () {
      final g = setup(
        GomokuVariant.renju,
        black: [(3, 7), (5, 7), (7, 7), (9, 7)],
        white: [(0, 0), (2, 0), (4, 0), (6, 0)],
      );
      expect(g.forbidden(g.index(6, 7)), Forbidden.doubleFour);
    });

    test('renju: exact five wins even when it also makes a four', () {
      final g = setup(
        GomokuVariant.renju,
        black: [(3, 7), (4, 7), (6, 7), (7, 7), (5, 4), (5, 5), (5, 6)],
        white: [(0, 0), (2, 0), (4, 0), (6, 0), (8, 0), (10, 0), (12, 0)],
      );
      expect(g.forbidden(g.index(5, 7)), isNull);
      expect(g.play(g.index(5, 7)), isTrue);
      expect(g.winner, GStone.black);
    });

    test('undo clears a win', () {
      final g = setup(
        GomokuVariant.freestyle,
        black: [(3, 7), (4, 7), (5, 7), (6, 7)],
        white: [(0, 0), (2, 0), (4, 0), (6, 0)],
      );
      g.play(g.index(7, 7));
      expect(g.winner, GStone.black);
      g.undo();
      expect(g.winner, isNull);
      expect(g.turn, GStone.black);
    });
  });
}
