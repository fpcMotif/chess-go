// Gomoku and renju rules. Written from the rules.
//
// Points are 0..size*size-1 with index = row * size + col.
//
// Variants:
// - freestyle: five or more in a row wins.
// - standard: exactly five wins; overlines do not count.
// - renju: black (first) wins only with exactly five and may not play
//   double-three, double-four or overline; such moves are refused. A move
//   that makes exactly five wins even if it is also a forbidden shape.
//   White wins with five or more and has no restrictions.

enum GStone {
  black,
  white;

  GStone get opposite => this == black ? white : black;
}

enum GomokuVariant { freestyle, standard, renju }

enum Forbidden { doubleThree, doubleFour, overline }

const _dirs = [
  [1, 0], [0, 1], [1, 1], [1, -1], //
];

class GomokuGame {
  GomokuGame({this.size = 15, this.variant = GomokuVariant.freestyle})
    : board = List.filled(size * size, null);

  final int size;
  final GomokuVariant variant;
  final List<GStone?> board;
  final List<int> moves = [];

  GStone? winner;

  /// The winning line, empty until someone wins.
  List<int> winningLine = const [];

  GStone get turn => moves.length.isEven ? GStone.black : GStone.white;
  bool get full => moves.length == board.length;
  bool get over => winner != null || full;
  int? get lastMove => moves.isEmpty ? null : moves.last;

  int index(int col, int row) => row * size + col;
  int colOf(int p) => p % size;
  int rowOf(int p) => p ~/ size;

  int? _step(int p, List<int> d, int k) {
    final c = colOf(p) + d[0] * k, r = rowOf(p) + d[1] * k;
    if (c < 0 || c >= size || r < 0 || r >= size) return null;
    return index(c, r);
  }

  /// Points of the run of [color] through [p] along [d], assuming [p]
  /// holds [color].
  List<int> _run(List<GStone?> b, int p, List<int> d, GStone color) {
    final out = [p];
    for (final s in const [1, -1]) {
      for (var k = 1; ; k++) {
        final q = _step(p, [d[0] * s, d[1] * s], k);
        if (q == null || b[q] != color) break;
        out.add(q);
      }
    }
    return out;
  }

  bool _exactFiveOnly(GStone color) =>
      variant == GomokuVariant.standard ||
      (variant == GomokuVariant.renju && color == GStone.black);

  /// The winning line if [color] on [p] makes a five, else null.
  List<int>? _five(List<GStone?> b, int p, GStone color) {
    for (final d in _dirs) {
      final run = _run(b, p, d, color);
      if (_exactFiveOnly(color) ? run.length == 5 : run.length >= 5) {
        return run;
      }
    }
    return null;
  }

  /// Why black may not play [p] under renju, or null if allowed.
  Forbidden? forbidden(int p) {
    if (variant != GomokuVariant.renju || board[p] != null) return null;
    return _forbidden(List.of(board), p, 0);
  }

  Forbidden? _forbidden(List<GStone?> b, int p, int depth) {
    b[p] = GStone.black;
    try {
      if (_five(b, p, GStone.black) != null) return null;
      for (final d in _dirs) {
        if (_run(b, p, d, GStone.black).length > 5) return Forbidden.overline;
      }
      var fours = 0, threes = 0;
      for (final d in _dirs) {
        fours += _fours(b, p, d);
        if (_isThree(b, p, d, depth)) threes++;
      }
      if (fours >= 2) return Forbidden.doubleFour;
      if (threes >= 2) return Forbidden.doubleThree;
      return null;
    } finally {
      b[p] = null;
    }
  }

  /// Empty points along [d] near [p] where black would make exactly five
  /// through [p].
  List<int> _fivePoints(List<GStone?> b, int p, List<int> d) {
    final out = <int>[];
    for (var k = -4; k <= 4; k++) {
      if (k == 0) continue;
      final q = _step(p, d, k);
      if (q == null || b[q] != null) continue;
      b[q] = GStone.black;
      if (_run(b, p, d, GStone.black).length == 5) out.add(q);
      b[q] = null;
    }
    return out;
  }

  /// Number of fours through [p] along [d]. An open four (two five points
  /// five apart) counts once; split patterns like X.XXX.X count twice.
  int _fours(List<GStone?> b, int p, List<int> d) {
    final pts = _fivePoints(b, p, d);
    if (pts.length == 2 && _distance(pts[0], pts[1]) == 5) return 1;
    return pts.length;
  }

  int _distance(int a, int b) {
    final dc = (colOf(a) - colOf(b)).abs(), dr = (rowOf(a) - rowOf(b)).abs();
    return dc > dr ? dc : dr;
  }

  /// A real three: one more black stone on this line, itself not
  /// forbidden, makes an open (straight) four through [p].
  bool _isThree(List<GStone?> b, int p, List<int> d, int depth) {
    for (var k = -4; k <= 4; k++) {
      if (k == 0) continue;
      final q = _step(p, d, k);
      if (q == null || b[q] != null) continue;
      b[q] = GStone.black;
      final pts = _fivePoints(b, p, d);
      final open = pts.length == 2 && _distance(pts[0], pts[1]) == 5;
      b[q] = null;
      if (!open) continue;
      if (depth >= 3 || _forbidden(b, q, depth + 1) == null) return true;
    }
    return false;
  }

  /// Plays at [p]. Returns false if occupied, forbidden, or over.
  bool play(int p) {
    if (over || board[p] != null) return false;
    if (turn == GStone.black && forbidden(p) != null) return false;
    final color = turn;
    board[p] = color;
    moves.add(p);
    final line = _five(board, p, color);
    if (line != null) {
      winner = color;
      winningLine = line;
    }
    return true;
  }

  bool undo() {
    if (moves.isEmpty) return false;
    board[moves.removeLast()] = null;
    winner = null;
    winningLine = const [];
    return true;
  }

  /// Star points for the usual 15x15 board.
  List<int> get starPoints {
    final m = size ~/ 2;
    final e = size >= 13 ? 3 : 2;
    return [
      index(m, m),
      index(e, e),
      index(size - 1 - e, e),
      index(e, size - 1 - e),
      index(size - 1 - e, size - 1 - e),
    ];
  }
}
