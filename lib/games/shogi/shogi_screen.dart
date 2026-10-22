import 'package:flutter/material.dart';

import '../../board/board_widget.dart';
import '../../board/game_layout.dart';
import '../../board/pieces.dart';
import 'shogi.dart';

BoardCoord _coord(int sq) => BoardCoord(sFile(sq), sRank(sq));
int _square(BoardCoord c) => sSquare(c.file, c.rank);

const shogiTheme = BoardTheme(
  light: Color(0xFFE9C47A),
  line: Color(0xFF4A3216),
  lastMove: Color(0x5533691E),
);

String shogiGlyph(SRole r, {bool gote = false}) => switch (r) {
  SRole.king => gote ? '玉' : '王',
  SRole.rook => '飛',
  SRole.bishop => '角',
  SRole.gold => '金',
  SRole.silver => '銀',
  SRole.knight => '桂',
  SRole.lance => '香',
  SRole.pawn => '歩',
  SRole.dragon => '龍',
  SRole.horse => '馬',
  SRole.promotedSilver => '全',
  SRole.promotedKnight => '圭',
  SRole.promotedLance => '杏',
  SRole.tokin => 'と',
};

Widget shogiPiece(SPiece p, {Key? key}) => ShogiPieceView(
  key: key,
  gote: p.side == SSide.gote,
  promoted: p.role.isPromoted,
  glyph: shogiGlyph(p.role, gote: p.side == SSide.gote),
  label: '${p.side.name} ${p.role.name}',
);

/// Local two-player shogi: board moves, drops from hand, promotion prompt.
class ShogiScreen extends StatefulWidget {
  const ShogiScreen({super.key, this.initialSfen});

  final String? initialSfen;

  @override
  State<ShogiScreen> createState() => _ShogiScreenState();
}

class _ShogiScreenState extends State<ShogiScreen> {
  late ShogiGame _game = _newGame();
  int? _selected;
  SRole? _dropRole;
  bool _flipped = false;
  SMove? _animate;
  int _token = 0;

  ShogiGame _newGame() => ShogiGame(
    widget.initialSfen == null ? null : SPosition.fromSfen(widget.initialSfen!),
  );

  SPosition get _pos => _game.position;
  bool get _over => _game.outcome != null;
  bool _own(int sq) => _pos[sq]?.side == _pos.turn;

  List<SMove> get _candidates {
    if (_dropRole != null) return _pos.dropsOf(_dropRole!);
    if (_selected != null) return _pos.movesFrom(_selected!);
    return const [];
  }

  void _clear() {
    _selected = null;
    _dropRole = null;
  }

  void _onTap(BoardCoord c) {
    if (_over) return;
    final sq = _square(c);
    final hits = _candidates.where((m) => m.to == sq).toList();
    if (hits.isNotEmpty) {
      _choose(hits, animate: _selected != null);
      return;
    }
    setState(() {
      final reselect = _selected != sq && _own(sq);
      _clear();
      if (reselect) _selected = sq;
    });
  }

  void _onDrop(BoardCoord from, BoardCoord? to) {
    if (to == null || _over) return;
    final f = _square(from), t = _square(to);
    if (f == t) {
      setState(() {
        _clear();
        _selected = f;
      });
      return;
    }
    final hits = _pos.movesFrom(f).where((m) => m.to == t).toList();
    if (hits.isEmpty) {
      setState(_clear);
    } else {
      _choose(hits, animate: false);
    }
  }

  void _onHandTap(SSide side, SRole role) {
    if (_over || side != _pos.turn || _pos.handCount(side, role) == 0) return;
    setState(() {
      final same = _dropRole == role;
      _clear();
      if (!same) _dropRole = role;
    });
  }

  Future<void> _choose(List<SMove> hits, {required bool animate}) async {
    var move = hits.first;
    if (hits.length > 1) {
      final promote = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Promote?'),
          actions: [
            TextButton(
              key: const ValueKey('promote-no'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              key: const ValueKey('promote-yes'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Promote'),
            ),
          ],
        ),
      );
      if (promote == null || !mounted) return;
      move = hits.firstWhere((m) => m.promote == promote);
    }
    setState(() {
      _game.play(move);
      _clear();
      _animate = animate && !move.isDrop ? move : null;
      _token++;
    });
  }

  String get _status {
    String name(SSide? s) => s == SSide.sente ? 'Sente' : 'Gote';
    final turn = name(_pos.turn);
    return switch (_game.outcome) {
      SOutcome.checkmate => 'Checkmate. ${name(_game.winner)} wins',
      SOutcome.perpetualCheck => 'Perpetual check. ${name(_game.winner)} wins',
      SOutcome.repetition => 'Draw by repetition (sennichite)',
      null => _pos.isCheck ? '$turn to move, check' : '$turn to move',
    };
  }

  Widget _hand(SSide side) {
    final pos = _pos;
    return SizedBox(
      key: ValueKey('hand-${side.name}'),
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final r in handRoles)
            if (pos.handCount(side, r) > 0)
              GestureDetector(
                key: ValueKey('hand-${side.name}-${r.name}'),
                onTap: () => _onHandTap(side, r),
                child: Container(
                  width: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: side == pos.turn && _dropRole == r
                        ? shogiTheme.selected
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: shogiPiece(SPiece(side, r))),
                      if (pos.handCount(side, r) > 1)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Text(
                            '${pos.handCount(side, r)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = _pos;
    final last = _game.lastMove;
    final king = pos.isCheck ? pos.kingSquare(pos.turn) : null;
    final board = BoardWidget(
      key: const ValueKey('shogi-board'),
      files: 9,
      ranks: 9,
      checkered: false,
      theme: shogiTheme,
      flipped: _flipped,
      pieces: {
        for (var sq = 0; sq < 81; sq++)
          if (pos[sq] != null)
            _coord(sq): shogiPiece(
              pos[sq]!,
              key: ValueKey('piece-${sSquareName(sq)}'),
            ),
      },
      selected: _selected == null ? null : _coord(_selected!),
      lastMove: last == null
          ? const []
          : [if (last.from != null) _coord(last.from!), _coord(last.to)],
      hints: {for (final m in _candidates) _coord(m.to)},
      check: king == null ? null : _coord(king),
      slides: _animate == null
          ? const {}
          : {_coord(_animate!.to): _coord(_animate!.from!)},
      slideToken: _token,
      onTap: _onTap,
      canDrag: (c) => !_over && _own(_square(c)),
      onDrop: _onDrop,
    );
    final topSide = _flipped ? SSide.sente : SSide.gote;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shogi'),
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
                    _clear();
                    _animate = null;
                  }),
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _game = _newGame();
              _clear();
              _animate = null;
            }),
          ),
        ],
      ),
      body: GameLayout(
        board: board,
        top: _hand(topSide),
        bottom: _hand(topSide.opposite),
        status: _status,
        panel: [
          Text('Moves: ${_game.moves.length}'),
          if (last != null) Text('Last: ${last.usi}'),
        ],
      ),
    );
  }
}
