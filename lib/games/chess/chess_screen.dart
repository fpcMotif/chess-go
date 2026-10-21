import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../board/board_widget.dart';
import 'chess.dart';

BoardCoord _coord(int sq) => BoardCoord(fileOf(sq), rankOf(sq));
int _square(BoardCoord c) => squareAt(c.file, c.rank);

/// Local two-player chess with legal-move hints.
class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key, this.initialFen});

  final String? initialFen;

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  late ChessGame _game = _newGame();
  int? _selected;
  bool _flipped = false;

  /// Move to animate on the next build: set only for tap moves, since a
  /// drag already shows the piece travelling.
  Move? _animate;
  int _token = 0;

  ChessGame _newGame() => ChessGame(
    widget.initialFen == null ? null : Position.fromFen(widget.initialFen!),
  );

  Position get _pos => _game.position;
  bool get _over => _game.outcome != null;

  bool _ownPiece(int sq) => _pos[sq]?.side == _pos.turn;

  void _onTap(BoardCoord c) {
    final sq = _square(c);
    if (_over) return;
    final sel = _selected;
    if (sel != null &&
        sel != sq &&
        _pos.movesFrom(sel).any((m) => m.to == sq)) {
      _tryMove(sel, sq, animate: true);
      return;
    }
    setState(() => _selected = (sel != sq && _ownPiece(sq)) ? sq : null);
  }

  void _onDrop(BoardCoord from, BoardCoord? to) {
    if (to == null || _over) return;
    final f = _square(from), t = _square(to);
    if (f == t) {
      setState(() => _selected = f);
      return;
    }
    _tryMove(f, t, animate: false);
  }

  Future<void> _tryMove(int from, int to, {required bool animate}) async {
    final candidates = _pos.movesFrom(from).where((m) => m.to == to).toList();
    if (candidates.isEmpty) {
      setState(() => _selected = null);
      return;
    }
    var move = candidates.first;
    if (candidates.length > 1) {
      final role = await _askPromotion(_pos.turn);
      if (role == null || !mounted) return;
      move = candidates.firstWhere((m) => m.promotion == role);
    }
    setState(() {
      _game.play(move);
      _selected = null;
      _animate = animate ? move : null;
      _token++;
    });
  }

  Future<Role?> _askPromotion(Side side) => showDialog<Role>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Promote to'),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final role in const [
              Role.queen,
              Role.rook,
              Role.bishop,
              Role.knight,
            ])
              InkWell(
                key: ValueKey('promote-${role.name}'),
                onTap: () => Navigator.pop(context, role),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ChessPieceView(Piece(side, role)),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  void _undo() => setState(() {
    _game.undo();
    _selected = null;
    _animate = null;
  });

  void _reset() => setState(() {
    _game = _newGame();
    _selected = null;
    _animate = null;
  });

  String get _status {
    final turn = _pos.turn == Side.white ? 'White' : 'Black';
    return switch (_game.outcome) {
      Outcome.checkmate =>
        'Checkmate. ${_game.winner == Side.white ? 'White' : 'Black'} wins',
      Outcome.stalemate => 'Draw by stalemate',
      Outcome.insufficientMaterial => 'Draw: insufficient material',
      Outcome.fiftyMoves => 'Draw: fifty-move rule',
      Outcome.threefold => 'Draw by threefold repetition',
      null => _pos.isCheck ? '$turn to move, check' : '$turn to move',
    };
  }

  Map<BoardCoord, BoardCoord> get _slides {
    final m = _animate;
    if (m == null) return const {};
    final slides = {_coord(m.to): _coord(m.from)};
    // Castling also moves the rook.
    if (_game.lastMove == m &&
        _pos[m.to]?.role == Role.king &&
        (m.to - m.from).abs() == 2) {
      final kingSide = m.to > m.from;
      final rookFrom = kingSide ? m.from + 3 : m.from - 4;
      final rookTo = kingSide ? m.from + 1 : m.from - 1;
      slides[_coord(rookTo)] = _coord(rookFrom);
    }
    return slides;
  }

  @override
  Widget build(BuildContext context) {
    final pos = _pos;
    final last = _game.lastMove;
    final king = pos.isCheck ? pos.kingSquare(pos.turn) : null;
    final board = BoardWidget(
      key: const ValueKey('chess-board'),
      files: 8,
      ranks: 8,
      flipped: _flipped,
      pieces: {
        for (var sq = 0; sq < 64; sq++)
          if (pos[sq] != null)
            _coord(sq): ChessPieceView(
              pos[sq]!,
              key: ValueKey('piece-${squareName(sq)}'),
            ),
      },
      selected: _selected == null ? null : _coord(_selected!),
      lastMove: last == null ? const [] : [_coord(last.from), _coord(last.to)],
      hints: _selected == null
          ? const {}
          : {for (final m in pos.movesFrom(_selected!)) _coord(m.to)},
      check: king == null ? null : _coord(king),
      slides: _slides,
      slideToken: _token,
      onTap: _onTap,
      canDrag: (c) => !_over && _ownPiece(_square(c)),
      onDrop: _onDrop,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: [
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => setState(() => _flipped = !_flipped),
          ),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _game.moves.isEmpty ? null : _undo,
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight;
            final side = _SidePanel(status: _status, sans: _game.sanHistory);
            final boardBox = Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? box.maxHeight : box.maxWidth,
                ),
                child: Padding(padding: const EdgeInsets.all(8), child: board),
              ),
            );
            return wide
                ? Row(
                    children: [
                      Expanded(flex: 3, child: boardBox),
                      Expanded(flex: 2, child: side),
                    ],
                  )
                : Column(
                    children: [
                      boardBox,
                      Expanded(child: side),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.status, required this.sans});

  final String status;
  final List<String> sans;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = <String>[
      for (var i = 0; i < sans.length; i += 2)
        '${i ~/ 2 + 1}. ${sans[i]}${i + 1 < sans.length ? '  ${sans[i + 1]}' : ''}',
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, key: const ValueKey('status'), style: text.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final r in rows)
                  Text(
                    r,
                    style: text.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a piece from the cburnett SVG set (GPLv2+, see assets README).
class ChessPieceView extends StatelessWidget {
  const ChessPieceView(this.piece, {super.key});

  final Piece piece;

  String get asset =>
      'assets/pieces/cburnett/${piece.side == Side.white ? 'w' : 'b'}'
      '${piece.role.letter.toUpperCase()}.svg';

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${piece.side.name} ${piece.role.name}',
    child: SvgPicture.asset(asset),
  );
}
