import 'package:flutter/material.dart';

import '../../board/board_widget.dart';
import '../../board/game_layout.dart';
import '../../board/pieces.dart';
import '../go/go_screen.dart' show goTheme;
import 'gomoku.dart';

String variantName(GomokuVariant v) => switch (v) {
  GomokuVariant.freestyle => 'Freestyle',
  GomokuVariant.standard => 'Standard',
  GomokuVariant.renju => 'Renju',
};

/// Local two-player gomoku or renju. In renju, black's forbidden points
/// are marked with a red cross and refused.
class GomokuScreen extends StatefulWidget {
  const GomokuScreen({super.key, this.variant = GomokuVariant.freestyle});

  final GomokuVariant variant;

  @override
  State<GomokuScreen> createState() => _GomokuScreenState();
}

class _GomokuScreenState extends State<GomokuScreen> {
  late GomokuGame _game = GomokuGame(variant: widget.variant);
  String? _notice;

  BoardCoord _coord(int p) => BoardCoord(_game.colOf(p), _game.rowOf(p));

  void _onTap(BoardCoord c) {
    final p = _game.index(c.file, c.rank);
    setState(() {
      final why = _game.turn == GStone.black ? _game.forbidden(p) : null;
      _notice = why == null || _game.over
          ? null
          : switch (why) {
              Forbidden.doubleThree => 'Forbidden for black: double three',
              Forbidden.doubleFour => 'Forbidden for black: double four',
              Forbidden.overline => 'Forbidden for black: overline',
            };
      _game.play(p);
    });
  }

  /// Forbidden points for black. Only points near black stones can be.
  Set<int> _forbiddenPoints() {
    final g = _game;
    if (g.variant != GomokuVariant.renju || g.turn != GStone.black || g.over) {
      return const {};
    }
    final out = <int>{};
    for (var p = 0; p < g.board.length; p++) {
      if (g.board[p] != null) continue;
      final c = g.colOf(p), r = g.rowOf(p);
      var near = false;
      for (final q in g.moves) {
        if (g.board[q] == GStone.black &&
            (g.colOf(q) - c).abs() <= 4 &&
            (g.rowOf(q) - r).abs() <= 4) {
          near = true;
          break;
        }
      }
      if (near && g.forbidden(p) != null) out.add(p);
    }
    return out;
  }

  String get _status {
    final g = _game;
    if (g.winner != null) {
      return '${g.winner == GStone.black ? 'Black' : 'White'} wins';
    }
    if (g.full) return 'Draw: board full';
    return '${g.turn == GStone.black ? 'Black' : 'White'} to move';
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final forbidden = _forbiddenPoints();
    final win = g.winningLine.toSet();
    final board = BoardWidget(
      key: const ValueKey('gomoku-board'),
      files: g.size,
      ranks: g.size,
      mode: BoardMode.intersections,
      theme: goTheme,
      starPoints: [for (final p in g.starPoints) _coord(p)],
      pieces: {
        for (var p = 0; p < g.board.length; p++)
          if (g.board[p] != null)
            _coord(p): StoneView(
              key: ValueKey('stone-$p'),
              black: g.board[p] == GStone.black,
              marker: p == g.lastMove || win.contains(p),
            )
          else if (forbidden.contains(p))
            _coord(p): const _ForbiddenMark(),
      },
      onTap: _onTap,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Gomoku: ${variantName(g.variant)}'),
        actions: [
          PopupMenuButton<GomokuVariant>(
            tooltip: 'Rules',
            icon: const Icon(Icons.rule),
            onSelected: (v) => setState(() {
              _game = GomokuGame(variant: v);
              _notice = null;
            }),
            itemBuilder: (_) => [
              for (final v in GomokuVariant.values)
                PopupMenuItem(value: v, child: Text('New ${variantName(v)}')),
            ],
          ),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: g.moves.isEmpty
                ? null
                : () => setState(() {
                    g.undo();
                    _notice = null;
                  }),
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _game = GomokuGame(variant: g.variant);
              _notice = null;
            }),
          ),
        ],
      ),
      body: GameLayout(
        board: board,
        status: _status,
        panel: [
          if (_notice != null)
            Text(
              _notice!,
              key: const ValueKey('notice'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Text(switch (g.variant) {
            GomokuVariant.freestyle => 'Five or more in a row wins.',
            GomokuVariant.standard => 'Exactly five in a row wins.',
            GomokuVariant.renju =>
              'Black: exactly five; no double three, double four or '
                  'overline (marked ×). White: five or more.',
          }),
        ],
      ),
    );
  }
}

class _ForbiddenMark extends StatelessWidget {
  const _ForbiddenMark();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      '×',
      style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold),
    ),
  );
}
