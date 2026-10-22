import 'package:chess_go/games/xiangqi/xiangqi.dart';
import 'package:flutter_test/flutter_test.dart';

int sq(String s) => xSquare(s.codeUnitAt(0) - 97, int.parse(s.substring(1)));
Set<String> targets(XPosition p, String from) => {
  for (final m in p.movesFrom(sq(from))) xSquareName(m.to),
};

void main() {
  group('xiangqi', () {
    test('start position has 44 moves and FEN round-trips', () {
      final p = XPosition.initial();
      expect(p.legalMoves.length, 44);
      expect(p.fen, xiangqiStartFen);
    });

    test('horse leg is blocked', () {
      // b0 horse: the leg toward d1 is c0, where the elephant stands.
      expect(targets(XPosition.initial(), 'b0'), {'a2', 'c2'});
    });

    test('cannon captures over exactly one screen', () {
      final t = targets(XPosition.initial(), 'b2');
      expect(t, contains('b9'));
      expect(t, isNot(contains('b7')));
      expect(t, contains('b6'));
    });

    test('elephant cannot cross the river, advisor stays in palace', () {
      final p = XPosition.fromFen('3k5/9/9/9/9/2B6/9/9/4A4/4K4 w');
      expect(targets(p, 'c4'), {'a2', 'e2'});
      expect(targets(p, 'e1'), {'d0', 'f0', 'd2', 'f2'});
    });

    test('soldier moves sideways only after crossing the river', () {
      final p = XPosition.fromFen('3k5/9/9/9/4P4/9/P8/9/9/4K4 w');
      expect(targets(p, 'a3'), {'a4'});
      expect(targets(p, 'e5'), {'e6', 'd5', 'f5'});
    });

    test('flying general: pinned blocker stays on the file', () {
      final p = XPosition.fromFen('4k4/9/9/9/9/9/9/9/4R4/4K4 w');
      expect(p.movesFrom(sq('e1')).every((m) => xFile(m.to) == 4), isTrue);
      expect(targets(p, 'e1'), contains('e9'));
    });

    test('checkmate', () {
      final g = XiangqiGame(XPosition.fromFen('R3k4/R8/9/9/9/9/9/9/9/3K5 b'));
      expect(g.position.isCheck, isTrue);
      expect(g.outcome, XOutcome.checkmate);
      expect(g.winner, XSide.red);
    });

    test('no legal move without check also loses', () {
      final g = XiangqiGame(XPosition.fromFen('3k5/R8/9/9/9/9/9/9/9/4K4 b'));
      expect(g.position.isCheck, isFalse);
      expect(g.outcome, XOutcome.stalemate);
      expect(g.winner, XSide.red);
    });

    test('perpetual check loses on threefold repetition', () {
      final g = XiangqiGame(XPosition.fromFen('4k4/9/9/9/9/9/9/9/9/R4K3 w'));
      const line = 'a0a9 e9e8 a9a8 e8e9 a8a9 e9e8 a9a8 e8e9 a8a9';
      for (final m in line.split(' ')) {
        expect(g.outcome, isNull, reason: m);
        final mv = XMove(sq(m.substring(0, 2)), sq(m.substring(2)));
        expect(g.position.legalMoves, contains(mv), reason: m);
        g.play(mv);
      }
      expect(g.outcome, XOutcome.perpetualCheck);
      expect(g.winner, XSide.black);
    });

    test('undo', () {
      final g = XiangqiGame();
      g.play(XMove(sq('b2'), sq('e2')));
      expect(g.undo(), isTrue);
      expect(g.position.fen, xiangqiStartFen);
    });

    test('perft matches published counts', () {
      int perft(XPosition p, int depth) {
        if (depth == 0) return 1;
        var n = 0;
        for (final m in p.legalMoves) {
          n += perft(p.play(m), depth - 1);
        }
        return n;
      }

      final start = XPosition.initial();
      expect([for (var d = 1; d <= 3; d++) perft(start, d)], [44, 1920, 79666]);
    });
  });
}
