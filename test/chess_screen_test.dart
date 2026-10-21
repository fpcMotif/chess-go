import 'package:chess_go/board/board_widget.dart';
import 'package:chess_go/games/chess/chess.dart';
import 'package:chess_go/games/chess/chess_screen.dart';
import 'package:chess_go/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _board = find.byKey(const ValueKey('chess-board'));

/// Screen position of a square's centre (board not flipped).
Offset _center(WidgetTester t, String sq) {
  final rect = t.getRect(_board);
  final cell = rect.width / 8;
  final s = parseSquare(sq);
  return rect.topLeft +
      Offset((fileOf(s) + 0.5) * cell, (7 - rankOf(s) + 0.5) * cell);
}

Future<void> _tap(WidgetTester t, String sq) async {
  await t.tapAt(_center(t, sq));
  await t.pumpAndSettle();
}

BoardWidget _boardWidget(WidgetTester t) => t.widget<BoardWidget>(_board);

String _status(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('status'))).data!;

Future<void> _pumpScreen(WidgetTester t, {String? fen}) async {
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: ChessScreen(initialFen: fen)));
}

void main() {
  testWidgets('home lists chess and opens it', (t) async {
    await t.pumpWidget(const ChessGoApp());
    await t.tap(find.text('Chess'));
    await t.pumpAndSettle();
    expect(_board, findsOneWidget);
    expect(_status(t), 'White to move');
  });

  testWidgets('tap shows legal hints, second tap moves', (t) async {
    await _pumpScreen(t);
    await _tap(t, 'e2');
    expect(_boardWidget(t).hints, {
      const BoardCoord(4, 2),
      const BoardCoord(4, 3),
    });
    await _tap(t, 'e4');
    expect(find.byKey(const ValueKey('piece-e4')), findsOneWidget);
    expect(find.byKey(const ValueKey('piece-e2')), findsNothing);
    expect(_boardWidget(t).lastMove, [
      const BoardCoord(4, 1),
      const BoardCoord(4, 3),
    ]);
    expect(_status(t), 'Black to move');
  });

  testWidgets('illegal target clears selection, no move', (t) async {
    await _pumpScreen(t);
    await _tap(t, 'e2');
    await _tap(t, 'e5');
    expect(_boardWidget(t).selected, isNull);
    expect(find.byKey(const ValueKey('piece-e2')), findsOneWidget);
  });

  testWidgets('cannot select opponent piece', (t) async {
    await _pumpScreen(t);
    await _tap(t, 'e7');
    expect(_boardWidget(t).selected, isNull);
  });

  testWidgets('drag and drop moves a piece', (t) async {
    await _pumpScreen(t);
    final g = await t.startGesture(_center(t, 'g1'));
    await g.moveTo(_center(t, 'g1') + const Offset(0, -20));
    await t.pump();
    await g.moveTo(_center(t, 'f3'));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('piece-f3')), findsOneWidget);
    expect(_status(t), 'Black to move');
  });

  testWidgets('promotion dialog picks piece', (t) async {
    await _pumpScreen(t, fen: '8/P6k/8/8/8/8/8/K7 w - - 0 1');
    await _tap(t, 'a7');
    await _tap(t, 'a8');
    expect(find.text('Promote to'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('promote-knight')));
    await t.pumpAndSettle();
    final piece = t.widget<ChessPieceView>(
      find.byKey(const ValueKey('piece-a8')),
    );
    expect(piece.piece, const Piece(Side.white, Role.knight));
  });

  testWidgets('checkmate status and undo', (t) async {
    await _pumpScreen(t);
    for (final (a, b) in [
      ('f2', 'f3'),
      ('e7', 'e5'),
      ('g2', 'g4'),
      ('d8', 'h4'),
    ]) {
      await _tap(t, a);
      await _tap(t, b);
    }
    expect(_status(t), 'Checkmate. Black wins');
    expect(_boardWidget(t).check, const BoardCoord(4, 0));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(_status(t), 'Black to move');
  });

  testWidgets('flip maps taps to the other side', (t) async {
    await _pumpScreen(t);
    await t.tap(find.byTooltip('Flip board'));
    await t.pumpAndSettle();
    // Flipped: the screen spot of e2 now holds d7.
    await _tap(t, 'e2');
    expect(_boardWidget(t).selected, isNull); // d7 is black's
    await _tap(t, 'd7'); // screen spot of e2 when flipped
    expect(_boardWidget(t).selected, const BoardCoord(4, 1));
  });
}
