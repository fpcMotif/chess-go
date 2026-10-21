import 'package:flutter/material.dart';

import '../../board/board_widget.dart';
import '../../board/game_layout.dart';
import '../../board/pieces.dart';
import 'xiangqi.dart';

BoardCoord _coord(int sq) => BoardCoord(xFile(sq), xRank(sq));
int _square(BoardCoord c) => xSquare(c.file, c.rank);

const xiangqiTheme = BoardTheme(
  light: Color(0xFFE8C68A),
  line: Color(0xFF5B3A1A),
  lastMove: Color(0x6633691E),
  selected: Color(0x8014551E),
);

String xiangqiGlyph(XPiece p) {
  final red = p.side == XSide.red;
  return switch (p.role) {
    XRole.general => red ? '帅' : '将',
    XRole.advisor => red ? '仕' : '士',
    XRole.elephant => red ? '相' : '象',
    XRole.horse => '马',
    XRole.chariot => '车',
    XRole.cannon => red ? '炮' : '砲',
    XRole.soldier => red ? '兵' : '卒',
  };
}

/// Local two-player xiangqi with legal-move hints.
class XiangqiScreen extends StatefulWidget {
  const XiangqiScreen({super.key, this.initialFen});

  final String? initialFen;

  @override
  State<XiangqiScreen> createState() => _XiangqiScreenState();
}

class _XiangqiScreenState extends State<XiangqiScreen> {
  late XiangqiGame _game = _newGame();
  int? _selected;
  bool _flipped = false;
  XMove? _animate;
  int _token = 0;

  XiangqiGame _newGame() => XiangqiGame(
    widget.initialFen == null ? null : XPosition.fromFen(widget.initialFen!),
  );

  XPosition get _pos => _game.position;
  bool get _over => _game.outcome != null;
  bool _own(int sq) => _pos[sq]?.side == _pos.turn;

  void _onTap(BoardCoord c) {
    if (_over) return;
    final sq = _square(c);
    final sel = _selected;
    if (sel != null && _pos.movesFrom(sel).contains(XMove(sel, sq))) {
      _move(XMove(sel, sq), animate: true);
      return;
    }
    setState(() => _selected = (sel != sq && _own(sq)) ? sq : null);
  }

  void _onDrop(BoardCoord from, BoardCoord? to) {
    if (to == null || _over) return;
    final m = XMove(_square(from), _square(to));
    if (m.from == m.to) {
      setState(() => _selected = m.from);
    } else if (_pos.movesFrom(m.from).contains(m)) {
      _move(m, animate: false);
    } else {
      setState(() => _selected = null);
    }
  }

  void _move(XMove m, {required bool animate}) => setState(() {
    _game.play(m);
    _selected = null;
    _animate = animate ? m : null;
    _token++;
  });

  String get _status {
    String name(XSide? s) => s == XSide.red ? 'Red' : 'Black';
    final turn = name(_pos.turn);
    return switch (_game.outcome) {
      XOutcome.checkmate => 'Checkmate. ${name(_game.winner)} wins',
      XOutcome.stalemate => 'No legal moves. ${name(_game.winner)} wins',
      XOutcome.perpetualCheck => 'Perpetual check. ${name(_game.winner)} wins',
      XOutcome.repetition => 'Draw by repetition',
      null => _pos.isCheck ? '$turn to move, check' : '$turn to move',
    };
  }

  @override
  Widget build(BuildContext context) {
    final pos = _pos;
    final last = _game.lastMove;
    final general = pos.isCheck ? pos.generalSquare(pos.turn) : null;
    final board = BoardWidget(
      key: const ValueKey('xiangqi-board'),
      files: 9,
      ranks: 10,
      mode: BoardMode.intersections,
      theme: xiangqiTheme,
      xiangqiMarks: true,
      flipped: _flipped,
      pieces: {
        for (var sq = 0; sq < 90; sq++)
          if (pos[sq] != null)
            _coord(sq): XiangqiPieceView(
              key: ValueKey('piece-${xSquareName(sq)}'),
              red: pos[sq]!.side == XSide.red,
              glyph: xiangqiGlyph(pos[sq]!),
              label: '${pos[sq]!.side.name} ${pos[sq]!.role.name}',
            ),
      },
      selected: _selected == null ? null : _coord(_selected!),
      lastMove: last == null ? const [] : [_coord(last.from), _coord(last.to)],
      hints: _selected == null
          ? const {}
          : {for (final m in pos.movesFrom(_selected!)) _coord(m.to)},
      check: general == null ? null : _coord(general),
      slides: _animate == null
          ? const {}
          : {_coord(_animate!.to): _coord(_animate!.from)},
      slideToken: _token,
      onTap: _onTap,
      canDrag: (c) => !_over && _own(_square(c)),
      onDrop: _onDrop,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xiangqi'),
        actions: [
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => setState(() => _flipped = !_flipped),
          ),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _game.moves.isEmpty
                ? null
                : () => setState(() {
                    _game.undo();
                    _selected = null;
                    _animate = null;
                  }),
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _game = _newGame();
              _selected = null;
              _animate = null;
            }),
          ),
        ],
      ),
      body: GameLayout(
        board: board,
        status: _status,
        panel: [Text('Moves: ${_game.moves.length}')],
      ),
    );
  }
}
