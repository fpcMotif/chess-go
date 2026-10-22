import 'package:chess_go/games/shogi/shogi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shogi', () {
    test('start position: 30 moves, SFEN round-trip', () {
      final p = SPosition.initial();
      expect(p.legalMoves.length, 30);
      expect('${p.sfen} 1', shogiStartSfen);
    });

    test('square names follow USI', () {
      expect(sSquareName(sSquare(0, 0)), '9i');
      expect(sSquareName(sSquare(8, 8)), '1a');
      expect(sParseSquare('7g'), sSquare(2, 2));
    });

    test('capture goes to hand unpromoted, then drop', () {
      final g = ShogiGame();
      for (final m in ['7g7f', '3c3d', '8h2b+']) {
        expect(g.position.legalMoves, contains(SMove.fromUsi(m)), reason: m);
        g.play(SMove.fromUsi(m));
      }
      expect(g.position.handCount(SSide.sente, SRole.bishop), 1);
      g.play(SMove.fromUsi('3a2b')); // silver takes horse
      expect(g.position.handCount(SSide.gote, SRole.bishop), 1);
      expect(g.position.legalMoves, contains(SMove.fromUsi('B*5e')));
      g.play(SMove.fromUsi('B*5e'));
      expect(g.position[sParseSquare('5e')]?.role, SRole.bishop);
      expect(g.position.handCount(SSide.sente, SRole.bishop), 0);
    });

    test('nifu: no second pawn on a file', () {
      final p = SPosition.fromSfen(
        'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b P 1',
      );
      expect(p.dropsOf(SRole.pawn), isEmpty);
    });

    test('pieces cannot be dropped where they could never move', () {
      final p = SPosition.fromSfen('4k4/9/9/9/9/9/9/9/4K4 b PLN 1');
      bool onRank(List<SMove> ms, int r) => ms.any((m) => sRank(m.to) == r);
      expect(onRank(p.dropsOf(SRole.pawn), 8), isFalse);
      expect(onRank(p.dropsOf(SRole.lance), 8), isFalse);
      expect(onRank(p.dropsOf(SRole.knight), 8), isFalse);
      expect(onRank(p.dropsOf(SRole.knight), 7), isFalse);
      expect(onRank(p.dropsOf(SRole.knight), 6), isTrue);
    });

    test('promotion optional in zone, forced when stuck', () {
      final p = SPosition.fromSfen('4k4/9/P8/1S7/9/9/9/9/4K4 b - 1');
      final pawn = p.movesFrom(sParseSquare('9c'));
      expect(pawn, [SMove.fromUsi('9c9b+'), SMove.fromUsi('9c9b')]);
      final p2 = SPosition.fromSfen('4k4/P8/9/9/9/9/9/9/4K4 b - 1');
      expect(p2.movesFrom(sParseSquare('9b')), [SMove.fromUsi('9b9a+')]);
      // Silver entering the zone may promote or not.
      final silver = p.movesFrom(sParseSquare('8d'));
      expect(silver, contains(SMove.fromUsi('8d8c+')));
      expect(silver, contains(SMove.fromUsi('8d8c')));
    });

    test('promoted pieces move like gold; dragon adds king steps', () {
      final p = SPosition.fromSfen('k8/9/9/9/4+P4/9/9/9/K8 b - 1');
      expect(p.movesFrom(sParseSquare('5e')).length, 6);
      final d = SPosition.fromSfen('k8/9/9/9/4+R4/9/9/9/K8 b - 1');
      expect(d.movesFrom(sParseSquare('5e')).length, 16 + 4);
    });

    test('uchifuzume: pawn-drop mate is illegal', () {
      final mate = SPosition.fromSfen('7lk/9/7G1/9/9/9/9/9/K8 b P 1');
      expect(
        mate.dropsOf(SRole.pawn).map((m) => m.usi),
        isNot(contains('P*1b')),
      );
      // Without the gold, the king can take the pawn, so the drop is fine.
      final ok = SPosition.fromSfen('7lk/9/9/9/9/9/9/9/K8 b P 1');
      expect(ok.dropsOf(SRole.pawn).map((m) => m.usi), contains('P*1b'));
    });

    test('checkmate', () {
      final g = ShogiGame(SPosition.fromSfen('8k/8G/8P/9/9/9/9/9/K8 w - 1'));
      expect(g.position.isCheck, isTrue);
      expect(g.outcome, SOutcome.checkmate);
      expect(g.winner, SSide.sente);
    });

    test('fourfold repetition is a draw', () {
      final g = ShogiGame(SPosition.fromSfen('4k4/9/9/9/9/9/9/9/4K4 b - 1'));
      for (var i = 0; i < 3; i++) {
        for (final m in ['5i4i', '5a4a', '4i5i', '4a5a']) {
          expect(g.outcome, isNull);
          g.play(SMove.fromUsi(m));
        }
      }
      expect(g.outcome, SOutcome.repetition);
      expect(g.winner, isNull);
    });

    test('perft matches published counts', () {
      int perft(SPosition p, int depth) {
        if (depth == 0) return 1;
        var n = 0;
        for (final m in p.legalMoves) {
          n += perft(p.play(m), depth - 1);
        }
        return n;
      }

      final start = SPosition.initial();
      expect([for (var d = 1; d <= 3; d++) perft(start, d)], [30, 900, 25470]);
    });
  });
}
