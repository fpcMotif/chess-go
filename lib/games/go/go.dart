// Go rules: captures, suicide ban, positional superko, Chinese area
// scoring with komi. Written from the rules.
//
// Points are 0..size*size-1 with index = row * size + col, row 0 at the
// bottom.

enum Stone {
  black,
  white;

  Stone get opposite => this == black ? white : black;
}

/// Why a move was refused.
enum GoIllegal { occupied, suicide, superko, gameOver }

class GoScore {
  const GoScore(this.black, this.white, this.komi);

  /// Area: live stones plus surrounded empty points.
  final int black;
  final int white;
  final double komi;

  /// Black minus white, komi included. Positive means black wins.
  double get margin => black - white - komi;
  Stone get winner => margin > 0 ? Stone.black : Stone.white;

  String get result {
    final m = margin.abs();
    final s = m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toString();
    return '${winner == Stone.black ? 'B' : 'W'}+$s';
  }
}

class _Snapshot {
  _Snapshot(this.board, this.turn, this.passes, this.captures, this.lastMove);
  final List<Stone?> board;
  final Stone turn;
  final int passes;
  final List<int> captures;
  final int? lastMove;
}

/// A game of Go. Two consecutive passes end play and start scoring, where
/// players mark dead groups with [toggleDead].
class GoGame {
  GoGame({this.size = 19, this.komi = 7.5})
    : board = List.filled(size * size, null) {
    _seen.add(_key(board));
  }

  final int size;
  final double komi;
  final List<Stone?> board;
  Stone turn = Stone.black;

  /// Consecutive passes.
  int passes = 0;

  /// Stones captured by black and by white.
  final List<int> captures = [0, 0];

  /// Last stone played, or null after a pass or at the start.
  int? lastMove;

  /// Set when a player resigns; that player loses.
  Stone? resigned;

  /// Dead stones marked during scoring.
  final Set<int> dead = {};

  final List<_Snapshot> _history = [];
  final Set<String> _seen = {};

  int get moveCount => _history.length;
  bool get scoring => passes >= 2 && resigned == null;
  bool get over => scoring || resigned != null;

  int index(int col, int row) => row * size + col;
  int colOf(int p) => p % size;
  int rowOf(int p) => p ~/ size;

  Iterable<int> neighbors(int p) sync* {
    final c = colOf(p), r = rowOf(p);
    if (c > 0) yield p - 1;
    if (c < size - 1) yield p + 1;
    if (r > 0) yield p - size;
    if (r < size - 1) yield p + size;
  }

  static String _key(List<Stone?> b) =>
      String.fromCharCodes(b.map((s) => s == null ? 46 : 66 + s.index * 21));

  /// The group containing [p] and its liberties.
  (Set<int>, Set<int>) group(List<Stone?> b, int p) {
    final color = b[p];
    final stones = <int>{p};
    final libs = <int>{};
    final stack = [p];
    while (stack.isNotEmpty) {
      final q = stack.removeLast();
      for (final n in neighbors(q)) {
        final s = b[n];
        if (s == null) {
          libs.add(n);
        } else if (s == color && stones.add(n)) {
          stack.add(n);
        }
      }
    }
    return (stones, libs);
  }

  /// Board after [turn] plays at [p], plus stones captured, or the reason
  /// it is illegal.
  (List<Stone?>?, int, GoIllegal?) _tryPlay(int p) {
    if (over) return (null, 0, GoIllegal.gameOver);
    if (board[p] != null) return (null, 0, GoIllegal.occupied);
    final b = List<Stone?>.of(board);
    b[p] = turn;
    var captured = 0;
    for (final n in neighbors(p)) {
      if (b[n] == turn.opposite) {
        final (stones, libs) = group(b, n);
        if (libs.isEmpty) {
          for (final s in stones) {
            b[s] = null;
          }
          captured += stones.length;
        }
      }
    }
    if (group(b, p).$2.isEmpty) return (null, 0, GoIllegal.suicide);
    if (_seen.contains(_key(b))) return (null, 0, GoIllegal.superko);
    return (b, captured, null);
  }

  GoIllegal? whyIllegal(int p) => _tryPlay(p).$3;
  bool isLegal(int p) => whyIllegal(p) == null;

  void _push() => _history.add(
    _Snapshot(List.of(board), turn, passes, List.of(captures), lastMove),
  );

  /// Plays a stone. Returns null on success, else the reason it failed.
  GoIllegal? play(int p) {
    final (b, captured, why) = _tryPlay(p);
    if (why != null) return why;
    _push();
    board.setAll(0, b!);
    captures[turn.index] += captured;
    _seen.add(_key(board));
    lastMove = p;
    passes = 0;
    turn = turn.opposite;
    return null;
  }

  void pass() {
    if (over) return;
    _push();
    passes++;
    lastMove = null;
    turn = turn.opposite;
    if (scoring) _guessDead();
  }

  void resign() {
    if (over) return;
    _push();
    resigned = turn;
  }

  bool undo() {
    if (_history.isEmpty) return false;
    final s = _history.removeLast();
    board.setAll(0, s.board);
    turn = s.turn;
    passes = s.passes;
    captures.setAll(0, s.captures);
    lastMove = s.lastMove;
    resigned = null;
    dead.clear();
    _seen
      ..clear()
      ..add(_key(List.filled(size * size, null)))
      ..addAll(_history.map((h) => _key(h.board)))
      ..add(_key(board));
    return true;
  }

  /// Marks or unmarks the whole group at [p] as dead during scoring.
  void toggleDead(int p) {
    if (!scoring || board[p] == null) return;
    final (stones, _) = group(board, p);
    if (dead.contains(p)) {
      dead.removeAll(stones);
    } else {
      dead.addAll(stones);
    }
  }

  /// Starting guess: groups with one liberty are dead.
  void _guessDead() {
    dead.clear();
    for (var p = 0; p < board.length; p++) {
      if (board[p] != null && !dead.contains(p)) {
        final (stones, libs) = group(board, p);
        if (libs.length <= 1) dead.addAll(stones);
      }
    }
  }

  /// Owner of each point under area scoring: live stones, and empty or
  /// dead-stone regions that touch only one colour.
  List<Stone?> territory() {
    final b = [
      for (var p = 0; p < board.length; p++) dead.contains(p) ? null : board[p],
    ];
    final owner = List<Stone?>.of(b);
    final done = List.filled(b.length, false);
    for (var p = 0; p < b.length; p++) {
      if (b[p] != null || done[p]) continue;
      final region = <int>[p];
      done[p] = true;
      final borders = <Stone>{};
      for (var i = 0; i < region.length; i++) {
        for (final n in neighbors(region[i])) {
          final s = b[n];
          if (s != null) {
            borders.add(s);
          } else if (!done[n]) {
            done[n] = true;
            region.add(n);
          }
        }
      }
      if (borders.length == 1) {
        for (final q in region) {
          owner[q] = borders.first;
        }
      }
    }
    return owner;
  }

  GoScore score() {
    final t = territory();
    return GoScore(
      t.where((s) => s == Stone.black).length,
      t.where((s) => s == Stone.white).length,
      komi,
    );
  }

  /// Star points for 9, 13 and 19 boards.
  List<int> get starPoints {
    final e = size >= 13 ? 3 : 2;
    final m = size ~/ 2;
    final lines = size >= 13 ? [e, m, size - 1 - e] : [e, size - 1 - e];
    return [
      for (final r in lines)
        for (final c in lines) index(c, r),
      if (size < 13) index(m, m),
    ];
  }
}
