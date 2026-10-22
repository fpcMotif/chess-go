import 'package:chess_go/board/board_widget.dart';
import 'package:chess_go/board/pieces.dart';
import 'package:chess_go/games/go/go_screen.dart';
import 'package:chess_go/games/gomoku/gomoku.dart';
import 'package:chess_go/games/gomoku/gomoku_screen.dart';
import 'package:chess_go/games/shogi/shogi_screen.dart';
import 'package:chess_go/games/xiangqi/xiangqi_screen.dart';
import 'package:chess_go/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screen centre of a board point (board not flipped).
Offset at(WidgetTester t, String key, int file, int rank) {
  final finder = find.byKey(ValueKey(key));
  final b = t.widget<BoardWidget>(finder);
  final rect = t.getRect(finder);
  final cell = rect.width / b.files;
  return rect.topLeft +
      Offset((file + 0.5) * cell, (b.ranks - 1 - rank + 0.5) * cell);
}

Future<void> tapAt(WidgetTester t, String key, int file, int rank) async {
  await t.tapAt(at(t, key, file, rank));
  await t.pumpAndSettle();
}

String status(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('status'))).data!;

Future<void> pump(WidgetTester t, Widget screen) async {
  t.view.physicalSize = const Size(800, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: screen));
}

void main() {
  for (final (name, key) in [
    ('Go', 'go-board'),
    ('Xiangqi', 'xiangqi-board'),
    ('Shogi', 'shogi-board'),
    ('Gomoku / Renju', 'gomoku-board'),
  ]) {
    testWidgets('home opens $name', (t) async {
      t.view.physicalSize = const Size(800, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const ChessGoApp());
      await t.tap(find.text(name));
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    });
  }

  group('go', () {
    const k = 'go-board';
    testWidgets('place, capture, pass twice to score', (t) async {
      await pump(t, const GoScreen(size: 9));
      expect(status(t), 'Black to move');
      // Black surrounds white at (1,1).
      for (final (c, r) in [(1, 0), (1, 1), (0, 1), (8, 8), (2, 1), (8, 7)]) {
        await tapAt(t, k, c, r);
      }
      await tapAt(t, k, 1, 2);
      final b = t.widget<BoardWidget>(find.byKey(const ValueKey(k)));
      expect(b.pieces.containsKey(const BoardCoord(1, 1)), isFalse);
      expect(find.textContaining('black 1'), findsOneWidget);

      await t.tap(find.text('Pass'));
      await t.pumpAndSettle();
      expect(status(t), contains('opponent passed'));
      await t.tap(find.text('Pass'));
      await t.pumpAndSettle();
      expect(status(t), startsWith('Game over: '));
      expect(find.text('Pass'), findsNothing);
    });

    testWidgets('suicide shows a notice', (t) async {
      await pump(t, const GoScreen(size: 9));
      for (final (c, r) in [(5, 5), (1, 0), (5, 6), (0, 1)]) {
        await tapAt(t, k, c, r);
      }
      await tapAt(t, k, 0, 0);
      expect(find.text('Suicide is not allowed'), findsOneWidget);
      expect(status(t), 'Black to move');
    });
  });

  group('xiangqi', () {
    const k = 'xiangqi-board';
    testWidgets('select shows hints, tap moves, undo', (t) async {
      await pump(t, const XiangqiScreen());
      await tapAt(t, k, 1, 2); // red cannon b2
      final hints = t.widget<BoardWidget>(find.byKey(const ValueKey(k))).hints;
      expect(hints, contains(const BoardCoord(4, 2)));
      expect(hints, contains(const BoardCoord(1, 9)));
      await tapAt(t, k, 4, 2); // centre cannon
      expect(find.byKey(const ValueKey('piece-e2')), findsOneWidget);
      expect(status(t), 'Black to move');
      await t.tap(find.byTooltip('Undo'));
      await t.pumpAndSettle();
      expect(status(t), 'Red to move');
    });

    testWidgets('checkmate status', (t) async {
      await pump(
        t,
        const XiangqiScreen(initialFen: '4k4/R8/9/9/9/9/9/9/9/1R1K5 w'),
      );
      await tapAt(t, k, 1, 0);
      await tapAt(t, k, 1, 9);
      expect(status(t), 'Checkmate. Red wins');
    });
  });

  group('shogi', () {
    const k = 'shogi-board';
    testWidgets('promotion prompt, capture to hand, drop', (t) async {
      await pump(t, const ShogiScreen());
      Future<void> move(String a, String b) async {
        await tapAt(t, k, 9 - int.parse(a[0]), 105 - a.codeUnitAt(1));
        await tapAt(t, k, 9 - int.parse(b[0]), 105 - b.codeUnitAt(1));
      }

      await move('7g', '7f');
      await move('3c', '3d');
      await move('8h', '2b'); // bishop trade: may promote
      expect(find.text('Promote?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('promote-yes')));
      await t.pumpAndSettle();
      final horse = t.widget<ShogiPieceView>(
        find.byKey(const ValueKey('piece-2b')),
      );
      expect(horse.glyph, '馬');
      expect(find.byKey(const ValueKey('hand-sente-bishop')), findsOneWidget);

      await move('3a', '2b'); // silver recaptures
      expect(find.byKey(const ValueKey('hand-gote-bishop')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('hand-sente-bishop')));
      await t.pumpAndSettle();
      final hints = t.widget<BoardWidget>(find.byKey(const ValueKey(k))).hints;
      expect(hints, contains(const BoardCoord(4, 4)));
      await tapAt(t, k, 4, 4); // drop on 5e
      expect(find.byKey(const ValueKey('piece-5e')), findsOneWidget);
      expect(find.byKey(const ValueKey('hand-sente-bishop')), findsNothing);
      expect(status(t), 'Gote to move');
    });
  });

  group('gomoku', () {
    const k = 'gomoku-board';
    testWidgets('five in a row wins', (t) async {
      await pump(t, const GomokuScreen());
      for (var i = 0; i < 4; i++) {
        await tapAt(t, k, 3 + i, 7);
        await tapAt(t, k, 3 + i, 9);
      }
      await tapAt(t, k, 7, 7);
      expect(status(t), 'Black wins');
    });

    testWidgets('renju refuses and marks double three', (t) async {
      await pump(t, const GomokuScreen(variant: GomokuVariant.renju));
      for (final (b, w) in [
        ((5, 7), (0, 0)),
        ((6, 7), (2, 0)),
        ((7, 5), (4, 0)),
        ((7, 6), (6, 0)),
      ]) {
        await tapAt(t, k, b.$1, b.$2);
        await tapAt(t, k, w.$1, w.$2);
      }
      expect(find.text('×'), findsWidgets);
      await tapAt(t, k, 7, 7);
      expect(find.text('Forbidden for black: double three'), findsOneWidget);
      expect(status(t), 'Black to move');
      final b = t.widget<BoardWidget>(find.byKey(const ValueKey(k)));
      expect(b.pieces[const BoardCoord(7, 7)], isNot(isA<StoneView>()));
    });
  });
}
