import 'package:chess_go/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open chess, play e4 by tap and Nf6 by drag', (t) async {
    app.main();
    await t.pumpAndSettle();
    await t.tap(find.text('Chess'));
    await t.pumpAndSettle();

    final board = find.byKey(const ValueKey('chess-board'));
    Offset at(int file, int rank) {
      final r = t.getRect(board);
      final cell = r.width / 8;
      return r.topLeft + Offset((file + 0.5) * cell, (7 - rank + 0.5) * cell);
    }

    await t.tapAt(at(4, 1)); // e2
    await t.pumpAndSettle();
    await t.tapAt(at(4, 3)); // e4
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('piece-e4')), findsOneWidget);

    final g = await t.startGesture(at(6, 7)); // g8
    await g.moveTo(at(6, 7) + const Offset(0, 20));
    await t.pump();
    await g.moveTo(at(5, 5)); // f6
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('piece-f6')), findsOneWidget);
    expect(find.text('White to move'), findsOneWidget);
  });

  testWidgets('each other game opens and takes a move', (t) async {
    app.main();
    await t.pumpAndSettle();
    for (final (name, key) in [
      ('Go', 'go-board'),
      ('Xiangqi', 'xiangqi-board'),
      ('Shogi', 'shogi-board'),
      ('Gomoku / Renju', 'gomoku-board'),
    ]) {
      await t.tap(find.text(name));
      await t.pumpAndSettle();
      final status = find.byKey(const ValueKey('status'));
      final before = t.widget<Text>(status).data;
      final board = find.byKey(ValueKey(key));
      final r = t.getRect(board);
      // Bottom-left area: (2,2) on Go/gomoku; on xiangqi/shogi tap a
      // piece then a free point straight ahead.
      final cols = key == 'xiangqi-board' || key == 'shogi-board' ? 9 : null;
      if (cols == null) {
        await t.tapAt(r.center);
      } else {
        final cell = r.width / cols;
        final rows = key == 'xiangqi-board' ? 10 : 9;
        Offset at(int f, int rk) =>
            r.topLeft + Offset((f + 0.5) * cell, (rows - 1 - rk + 0.5) * cell);
        // Xiangqi: soldier a3 to a4. Shogi: pawn 9g to 9f.
        final (from, to) = key == 'xiangqi-board' ? (3, 4) : (2, 3);
        await t.tapAt(at(0, from));
        await t.pumpAndSettle();
        await t.tapAt(at(0, to));
      }
      await t.pumpAndSettle();
      expect(t.widget<Text>(status).data, isNot(before), reason: name);
      await t.pageBack();
      await t.pumpAndSettle();
    }
  });
}
