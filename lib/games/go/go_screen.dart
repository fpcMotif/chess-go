import 'package:flutter/material.dart';

import '../../board/board_widget.dart';
import '../../board/game_layout.dart';
import '../../board/pieces.dart';
import 'go.dart';

const goTheme = BoardTheme(
  light: Color(0xFFDCB35C),
  line: Color(0xFF2B1D0E),
  lastMove: Color(0x00000000),
);

/// Local two-player Go. After two passes, tap groups to mark them dead;
/// the area score updates live.
class GoScreen extends StatefulWidget {
  const GoScreen({super.key, this.size = 19});

  final int size;

  @override
  State<GoScreen> createState() => _GoScreenState();
}

class _GoScreenState extends State<GoScreen> {
  late GoGame _game = GoGame(size: widget.size);
  String? _notice;

  BoardCoord _coord(int p) => BoardCoord(_game.colOf(p), _game.rowOf(p));

  void _onTap(BoardCoord c) {
    final p = _game.index(c.file, c.rank);
    setState(() {
      if (_game.scoring) {
        _game.toggleDead(p);
        _notice = null;
        return;
      }
      _notice = switch (_game.play(p)) {
        GoIllegal.suicide => 'Suicide is not allowed',
        GoIllegal.superko => 'Superko: that repeats an earlier position',
        _ => null,
      };
    });
  }

  void _newGame(int size) => setState(() {
    _game = GoGame(size: size);
    _notice = null;
  });

  String get _status {
    if (_game.resigned != null) {
      final winner = _game.resigned == Stone.black ? 'White' : 'Black';
      return '$winner wins by resignation';
    }
    if (_game.scoring) return 'Game over: ${_game.score().result}';
    final turn = _game.turn == Stone.black ? 'Black' : 'White';
    return _game.passes == 1
        ? '$turn to move (opponent passed)'
        : '$turn to move';
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final territory = g.scoring ? g.territory() : null;
    final board = BoardWidget(
      key: const ValueKey('go-board'),
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
              black: g.board[p] == Stone.black,
              marker: p == g.lastMove,
              faded: g.dead.contains(p),
            )
          else if (territory?[p] != null)
            _coord(p): _TerritoryMark(black: territory![p] == Stone.black),
      },
      onTap: _onTap,
    );
    final score = g.scoring ? g.score() : null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Go ${g.size}×${g.size}'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Board size',
            icon: const Icon(Icons.grid_on),
            onSelected: _newGame,
            itemBuilder: (_) => [
              for (final s in const [9, 13, 19])
                PopupMenuItem(value: s, child: Text('New $s×$s game')),
            ],
          ),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: g.moveCount == 0
                ? null
                : () => setState(() {
                    g.undo();
                    _notice = null;
                  }),
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: () => _newGame(g.size),
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
          Text(
            'Captures: black ${g.captures[0]}, white ${g.captures[1]}. '
            'Komi ${g.komi}.',
          ),
          if (score != null)
            Text(
              'Area: black ${score.black}, white ${score.white} + ${g.komi}. '
              'Tap a group to mark it dead or alive.',
            ),
          const SizedBox(height: 8),
          if (!g.over)
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => setState(() {
                    g.pass();
                    _notice = null;
                  }),
                  child: const Text('Pass'),
                ),
                OutlinedButton(
                  onPressed: () => setState(g.resign),
                  child: const Text('Resign'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TerritoryMark extends StatelessWidget {
  const _TerritoryMark({required this.black});
  final bool black;

  @override
  Widget build(BuildContext context) => Center(
    child: FractionallySizedBox(
      widthFactor: 0.3,
      heightFactor: 0.3,
      child: ColoredBox(color: black ? Colors.black : Colors.white),
    ),
  );
}
