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
}
