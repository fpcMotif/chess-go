import 'package:chess_go/games/go/go.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('go', () {
    test('captures a surrounded stone', () {
      final g = GoGame(size: 9);
      // B c(1,1) is surrounded by white on four sides.
      for (final (c, r) in [(1, 1), (1, 2), (8, 8), (0, 1), (8, 7), (2, 1)]) {
        expect(g.play(g.index(c, r)), isNull);
      }
      expect(g.board[g.index(1, 1)], Stone.black);
      g.pass(); // black
      expect(g.play(g.index(1, 0)), isNull); // white captures
      expect(g.board[g.index(1, 1)], isNull);
      expect(g.captures[Stone.white.index], 1);
    });

    test('suicide is illegal, capturing is not suicide', () {
      final g = GoGame(size: 9);
      // White stones around (0,0): (1,0) and (0,1).
      g.play(g.index(5, 5)); // B
      g.play(g.index(1, 0)); // W
      g.play(g.index(5, 6)); // B
      g.play(g.index(0, 1)); // W
      expect(g.whyIllegal(g.index(0, 0)), GoIllegal.suicide);
      expect(g.whyIllegal(g.index(1, 0)), GoIllegal.occupied);
    });

    test('superko forbids immediate ko recapture', () {
      final g = GoGame(size: 9);
      for (final m in [
        (1, 2), (2, 2), (0, 1), (1, 1), (1, 0), (3, 1), null, (2, 0), //
      ]) {
        if (m == null) {
          g.pass();
        } else {
          expect(g.play(g.index(m.$1, m.$2)), isNull, reason: '$m');
        }
      }
      expect(g.play(g.index(2, 1)), isNull); // black takes the ko
      expect(g.board[g.index(1, 1)], isNull);
      expect(g.play(g.index(1, 1)), GoIllegal.superko);
      // After a ko threat elsewhere white may retake.
      g.play(g.index(7, 7));
      g.play(g.index(7, 6));
      expect(g.play(g.index(1, 1)), isNull);
      expect(g.board[g.index(2, 1)], isNull);
    });

    test('undo restores board and superko history', () {
      final g = GoGame(size: 9);
      g.play(g.index(4, 4));
      g.play(g.index(3, 3));
      expect(g.undo(), isTrue);
      expect(g.board[g.index(3, 3)], isNull);
      expect(g.turn, Stone.white);
      expect(g.play(g.index(3, 3)), isNull);
    });

    test('area scoring with komi and dead stones', () {
      final g = GoGame(size: 9);
      for (var r = 0; r < 9; r++) {
        g.play(g.index(3, r));
        g.play(g.index(5, r));
      }
      // A lone white stone inside black's area.
      g.pass();
      g.play(g.index(0, 0));
      g.pass();
      g.pass();
      expect(g.scoring, isTrue);
      // White (0,0) has 2 liberties so it is not guessed dead.
      expect(g.dead, isEmpty);
      var s = g.score();
      expect(s.black, 9); // area at cols 0..2 is shared, so neutral
      expect(s.white, 36 + 1);
      g.toggleDead(g.index(0, 0));
      s = g.score();
      expect(s.black, 36);
      expect(s.white, 36);
      expect(s.result, 'W+7.5');
      g.toggleDead(g.index(0, 0));
      expect(g.dead, isEmpty);
    });

    test('empty board goes to white by komi', () {
      final g = GoGame(size: 9)
        ..pass()
        ..pass();
      expect(g.score().result, 'W+7.5');
      expect(g.play(0), GoIllegal.gameOver);
    });

    test('star points', () {
      expect(GoGame(size: 19).starPoints.length, 9);
      expect(GoGame(size: 13).starPoints.length, 9);
      expect(GoGame(size: 9).starPoints.length, 5);
    });
  });
}
