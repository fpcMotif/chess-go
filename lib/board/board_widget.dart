import 'package:flutter/material.dart';

/// How pieces sit on the board.
enum BoardMode {
  /// Pieces go inside cells (chess, shogi).
  squares,

  /// Pieces go on line crossings (Go, xiangqi, gomoku).
  intersections,
}

/// A point on the board. File 0 is the left column and rank 0 the bottom
/// row, from the first player's view.
@immutable
class BoardCoord {
  const BoardCoord(this.file, this.rank);
  final int file;
  final int rank;

  @override
  bool operator ==(Object other) =>
      other is BoardCoord && other.file == file && other.rank == rank;

  @override
  int get hashCode => file * 31 + rank;

  @override
  String toString() => '($file,$rank)';
}

/// Colours for a board. Defaults follow the classic brown chess board.
@immutable
class BoardTheme {
  const BoardTheme({
    this.light = const Color(0xFFF0D9B5),
    this.dark = const Color(0xFFB58863),
    this.line = const Color(0xFF3E2A14),
    this.lastMove = const Color(0x809BC700),
    this.selected = const Color(0x8014551E),
    this.hint = const Color(0x4D000000),
    this.check = const Color(0xCCFF2020),
  });

  final Color light;
  final Color dark;
  final Color line;
  final Color lastMove;
  final Color selected;
  final Color hint;
  final Color check;
}

/// Generic game board: draws cells or a grid, highlights, legal-move hint
/// dots, and pieces. Handles tap and drag and animates piece slides.
///
/// It knows nothing about game rules; callers map their own squares to
/// [BoardCoord] and decide what each tap or drop means.
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.files,
    required this.ranks,
    this.mode = BoardMode.squares,
    this.flipped = false,
    this.pieces = const {},
    this.selected,
    this.lastMove = const [],
    this.hints = const {},
    this.check,
    this.slides = const {},
    this.slideToken = 0,
    this.slideDuration = const Duration(milliseconds: 180),
    this.theme = const BoardTheme(),
    this.onTap,
    this.canDrag,
    this.onDrop,
  });

  final int files;
  final int ranks;
  final BoardMode mode;

  /// Shows the board from the second player's side.
  final bool flipped;

  /// Widget for each occupied point.
  final Map<BoardCoord, Widget> pieces;

  final BoardCoord? selected;

  /// Points to tint as the last move (usually from and to).
  final List<BoardCoord> lastMove;

  /// Legal targets for the selected piece. Occupied targets get a ring,
  /// empty ones a dot.
  final Set<BoardCoord> hints;

  /// Point to mark red (king in check).
  final BoardCoord? check;

  /// Pieces to animate: destination -> origin. Played when [slideToken]
  /// changes.
  final Map<BoardCoord, BoardCoord> slides;
  final int slideToken;
  final Duration slideDuration;

  final BoardTheme theme;

  final ValueChanged<BoardCoord>? onTap;

  /// Whether the piece at a point may be dragged.
  final bool Function(BoardCoord)? canDrag;

  /// Drag released over [to] (null when dropped off the board).
  final void Function(BoardCoord from, BoardCoord? to)? onDrop;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  BoardCoord? _dragFrom;
  Offset? _dragPos;

  /// Columns and rows of the layout grid. Intersection boards have one
  /// cell per point, with lines drawn through cell centres.
  int get _cols => widget.files;
  int get _rows => widget.ranks;

  Offset _topLeft(BoardCoord c, double cell) {
    final col = widget.flipped ? _cols - 1 - c.file : c.file;
    final row = widget.flipped ? c.rank : _rows - 1 - c.rank;
    return Offset(col * cell, row * cell);
  }

  BoardCoord? _coordAt(Offset p, double cell) {
    final col = (p.dx / cell).floor();
    final row = (p.dy / cell).floor();
    if (col < 0 || col >= _cols || row < 0 || row >= _rows) return null;
    final file = widget.flipped ? _cols - 1 - col : col;
    final rank = widget.flipped ? row : _rows - 1 - row;
    return BoardCoord(file, rank);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _cols / _rows,
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = box.maxWidth / _cols;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final c = _coordAt(d.localPosition, cell);
              if (c != null) widget.onTap?.call(c);
            },
            onPanStart: (d) {
              final c = _coordAt(d.localPosition, cell);
              if (c == null || !widget.pieces.containsKey(c)) return;
              if (!(widget.canDrag?.call(c) ?? false)) return;
              setState(() {
                _dragFrom = c;
                _dragPos = d.localPosition;
              });
            },
            onPanUpdate: (d) {
              if (_dragFrom == null) return;
              setState(() => _dragPos = d.localPosition);
            },
            onPanEnd: (_) {
              final from = _dragFrom;
              final pos = _dragPos;
              setState(() {
                _dragFrom = null;
                _dragPos = null;
              });
              if (from != null && pos != null) {
                widget.onDrop?.call(from, _coordAt(pos, cell));
              }
            },
            onPanCancel: () => setState(() {
              _dragFrom = null;
              _dragPos = null;
            }),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BoardPainter(
                      cols: _cols,
                      rows: _rows,
                      mode: widget.mode,
                      theme: widget.theme,
                      marks: [
                        for (final c in widget.lastMove)
                          (_topLeft(c, cell), widget.theme.lastMove),
                        if (widget.selected != null)
                          (
                            _topLeft(widget.selected!, cell),
                            widget.theme.selected,
                          ),
                      ],
                      check: widget.check == null
                          ? null
                          : _topLeft(widget.check!, cell),
                    ),
                  ),
                ),
                for (final e in widget.pieces.entries)
                  if (e.key != _dragFrom) _piece(e.key, e.value, cell),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HintPainter(
                        color: widget.theme.hint,
                        cell: cell,
                        targets: [
                          for (final c in widget.hints)
                            (_topLeft(c, cell), widget.pieces.containsKey(c)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_dragFrom != null && _dragPos != null)
                  Positioned(
                    left: _dragPos!.dx - cell * 0.6,
                    top: _dragPos!.dy - cell * 0.6,
                    width: cell * 1.2,
                    height: cell * 1.2,
                    child: IgnorePointer(child: widget.pieces[_dragFrom]!),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _piece(BoardCoord at, Widget child, double cell) {
    final end = _topLeft(at, cell);
    final from = widget.slides[at];
    final square = SizedBox(width: cell, height: cell, child: child);
    if (from == null) {
      return Positioned(left: end.dx, top: end.dy, child: square);
    }
    final start = _topLeft(from, cell);
    return TweenAnimationBuilder<Offset>(
      key: ValueKey('slide-${widget.slideToken}-$at'),
      tween: Tween(begin: start, end: end),
      duration: widget.slideDuration,
      curve: Curves.easeOutCubic,
      builder: (context, o, child) =>
          Positioned(left: o.dx, top: o.dy, child: child!),
      child: square,
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.cols,
    required this.rows,
    required this.mode,
    required this.theme,
    required this.marks,
    required this.check,
  });

  final int cols;
  final int rows;
  final BoardMode mode;
  final BoardTheme theme;
  final List<(Offset, Color)> marks;
  final Offset? check;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cols;
    final paint = Paint();
    if (mode == BoardMode.squares) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          // Bottom-left cell is dark, as on a chess board.
          paint.color = (r + c) % 2 == (rows - 1) % 2
              ? theme.dark
              : theme.light;
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    } else {
      paint.color = theme.light;
      canvas.drawRect(Offset.zero & size, paint);
      final line = Paint()
        ..color = theme.line
        ..strokeWidth = 1;
      final h = cell / 2;
      for (var c = 0; c < cols; c++) {
        canvas.drawLine(
          Offset(h + c * cell, h),
          Offset(h + c * cell, size.height - h),
          line,
        );
      }
      for (var r = 0; r < rows; r++) {
        canvas.drawLine(
          Offset(h, h + r * cell),
          Offset(size.width - h, h + r * cell),
          line,
        );
      }
    }
    for (final (o, color) in marks) {
      paint.color = color;
      if (mode == BoardMode.squares) {
        canvas.drawRect(o & Size(cell, cell), paint);
      } else {
        canvas.drawCircle(o + Offset(cell / 2, cell / 2), cell * 0.45, paint);
      }
    }
    if (check != null) {
      final center = check! + Offset(cell / 2, cell / 2);
      canvas.drawCircle(
        center,
        cell * 0.6,
        Paint()
          ..shader = RadialGradient(
            colors: [theme.check, theme.check.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: center, radius: cell * 0.6)),
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.mode != mode ||
      old.theme != theme ||
      old.check != check ||
      !_sameMarks(old.marks, marks);

  static bool _sameMarks(List<(Offset, Color)> a, List<(Offset, Color)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _HintPainter extends CustomPainter {
  _HintPainter({
    required this.color,
    required this.cell,
    required this.targets,
  });

  final Color color;
  final double cell;

  /// Top-left of each target cell and whether it holds a piece.
  final List<(Offset, bool)> targets;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = color;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.08;
    for (final (o, occupied) in targets) {
      final c = o + Offset(cell / 2, cell / 2);
      if (occupied) {
        canvas.drawCircle(c, cell * 0.46, ring);
      } else {
        canvas.drawCircle(c, cell * 0.16, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_HintPainter old) =>
      old.cell != cell ||
      old.color != color ||
      old.targets.length != targets.length ||
      !List.generate(
        targets.length,
        (i) => old.targets[i] == targets[i],
      ).every((x) => x);
}
