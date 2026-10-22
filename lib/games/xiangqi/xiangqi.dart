// Xiangqi (Chinese chess) rules: move generation, flying general, check,
// mate, and a simplified repetition rule. Written from the rules.
//
// Squares are 0..89 with index = rank * 9 + file. Red is at the bottom
// (ranks 0..4) and moves first.

enum XSide {
  red,
  black;

  XSide get opposite => this == red ? black : red;
}

enum XRole {
  general('k'),
  advisor('a'),
  elephant('b'),
  horse('n'),
  chariot('r'),
  cannon('c'),
  soldier('p');

  const XRole(this.letter);
  final String letter;

  static XRole fromLetter(String c) {
    final l = c.toLowerCase();
    // Accept the common alternative letters too.
    if (l == 'e') return elephant;
    if (l == 'h') return horse;
    return XRole.values.firstWhere((r) => r.letter == l);
  }
}

class XPiece {
  const XPiece(this.side, this.role);
  final XSide side;
  final XRole role;

  String get fenChar =>
      side == XSide.red ? role.letter.toUpperCase() : role.letter;

  @override
  bool operator ==(Object other) =>
      other is XPiece && other.side == side && other.role == role;

  @override
  int get hashCode => side.index * 8 + role.index;
}

class XMove {
  const XMove(this.from, this.to);
  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      other is XMove && other.from == from && other.to == to;

  @override
  int get hashCode => from * 90 + to;

  @override
  String toString() => '${xSquareName(from)}${xSquareName(to)}';
}

int xFile(int sq) => sq % 9;
int xRank(int sq) => sq ~/ 9;
int xSquare(int file, int rank) => rank * 9 + file;
String xSquareName(int sq) =>
    '${String.fromCharCode(97 + xFile(sq))}${xRank(sq)}';

const xiangqiStartFen =
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w';

const _orth = [
  [1, 0], [-1, 0], [0, 1], [0, -1], //
];
const _diag = [
  [1, 1], [1, -1], [-1, 1], [-1, -1], //
];

/// Immutable xiangqi position.
class XPosition {
  XPosition._(this.board, this.turn);

  final List<XPiece?> board;
  final XSide turn;

  factory XPosition.initial() => XPosition.fromFen(xiangqiStartFen);

  /// Parses FEN with red uppercase; side is `w`/`r` for red, `b` for black.
  factory XPosition.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final rows = parts[0].split('/');
    if (rows.length != 10) throw FormatException('bad xiangqi FEN: $fen');
    final board = List<XPiece?>.filled(90, null);
    for (var i = 0; i < 10; i++) {
      final rank = 9 - i;
      var file = 0;
      for (final ch in rows[i].split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          file += n;
        } else {
          if (file > 8) throw FormatException('bad xiangqi FEN: $fen');
          final side = ch == ch.toUpperCase() ? XSide.red : XSide.black;
          board[xSquare(file, rank)] = XPiece(side, XRole.fromLetter(ch));
          file++;
        }
      }
      if (file != 9) throw FormatException('bad xiangqi FEN: $fen');
    }
    final turn = parts.length > 1 && parts[1] == 'b' ? XSide.black : XSide.red;
    return XPosition._(board, turn);
  }

  String get fen {
    final rows = <String>[];
    for (var rank = 9; rank >= 0; rank--) {
      final sb = StringBuffer();
      var empty = 0;
      for (var file = 0; file < 9; file++) {
        final p = board[xSquare(file, rank)];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) sb.write(empty);
          empty = 0;
          sb.write(p.fenChar);
        }
      }
      if (empty > 0) sb.write(empty);
      rows.add(sb.toString());
    }
    return '${rows.join('/')} ${turn == XSide.red ? 'w' : 'b'}';
  }

  XPiece? operator [](int sq) => board[sq];

  static bool _inPalace(XSide side, int file, int rank) =>
      file >= 3 &&
      file <= 5 &&
      (side == XSide.red ? rank >= 0 && rank <= 2 : rank >= 7 && rank <= 9);

  static bool _ownHalf(XSide side, int rank) =>
      side == XSide.red ? rank <= 4 : rank >= 5;

  /// Moves for the piece on [from], ignoring whether they leave the own
  /// general in check.
  List<int> _pseudoTargets(int from) {
    final p = board[from];
    if (p == null) return const [];
    final f = xFile(from), r = xRank(from);
    final out = <int>[];
    bool on(int ff, int rr) => ff >= 0 && ff < 9 && rr >= 0 && rr < 10;
    void add(int ff, int rr) {
      final q = board[xSquare(ff, rr)];
      if (q == null || q.side != p.side) out.add(xSquare(ff, rr));
    }

    switch (p.role) {
      case XRole.general:
        for (final d in _orth) {
          final ff = f + d[0], rr = r + d[1];
          if (_inPalace(p.side, ff, rr)) add(ff, rr);
        }
      case XRole.advisor:
        for (final d in _diag) {
          final ff = f + d[0], rr = r + d[1];
          if (_inPalace(p.side, ff, rr)) add(ff, rr);
        }
      case XRole.elephant:
        for (final d in _diag) {
          final ff = f + 2 * d[0], rr = r + 2 * d[1];
          if (!on(ff, rr) || !_ownHalf(p.side, rr)) continue;
          if (board[xSquare(f + d[0], r + d[1])] != null) continue;
          add(ff, rr);
        }
      case XRole.horse:
        for (final d in _orth) {
          final lf = f + d[0], lr = r + d[1];
          if (!on(lf, lr) || board[xSquare(lf, lr)] != null) continue;
          // Two diagonal steps beyond the unblocked leg.
          for (final s in [-1, 1]) {
            final ff = lf + (d[0] == 0 ? s : d[0]);
            final rr = lr + (d[1] == 0 ? s : d[1]);
            if (on(ff, rr)) add(ff, rr);
          }
        }
      case XRole.chariot:
        for (final d in _orth) {
          var ff = f + d[0], rr = r + d[1];
          while (on(ff, rr)) {
            add(ff, rr);
            if (board[xSquare(ff, rr)] != null) break;
            ff += d[0];
            rr += d[1];
          }
        }
      case XRole.cannon:
        for (final d in _orth) {
          var ff = f + d[0], rr = r + d[1];
          var screened = false;
          while (on(ff, rr)) {
            final q = board[xSquare(ff, rr)];
            if (!screened) {
              if (q == null) {
                out.add(xSquare(ff, rr));
              } else {
                screened = true;
              }
            } else if (q != null) {
              if (q.side != p.side) out.add(xSquare(ff, rr));
              break;
            }
            ff += d[0];
            rr += d[1];
          }
        }
      case XRole.soldier:
        final fwd = p.side == XSide.red ? 1 : -1;
        if (on(f, r + fwd)) add(f, r + fwd);
        if (!_ownHalf(p.side, r)) {
          if (f > 0) add(f - 1, r);
          if (f < 8) add(f + 1, r);
        }
    }
    return out;
  }

  int? generalSquare(XSide side) {
    for (var sq = 0; sq < 90; sq++) {
      final p = board[sq];
      if (p != null && p.side == side && p.role == XRole.general) return sq;
    }
    return null;
  }

  /// Whether [side]'s general is attacked, counting facing generals.
  bool inCheck(XSide side) {
    final g = generalSquare(side);
    if (g == null) return true;
    final other = generalSquare(side.opposite);
    if (other != null && xFile(other) == xFile(g)) {
      final lo = g < other ? g : other, hi = g < other ? other : g;
      var clear = true;
      for (var sq = lo + 9; sq < hi; sq += 9) {
        if (board[sq] != null) {
          clear = false;
          break;
        }
      }
      if (clear) return true;
    }
    for (var sq = 0; sq < 90; sq++) {
      final p = board[sq];
      if (p != null &&
          p.side != side &&
          p.role != XRole.general &&
          _pseudoTargets(sq).contains(g)) {
        return true;
      }
    }
    return false;
  }

  bool get isCheck => inCheck(turn);

  XPosition play(XMove m) {
    final b = List<XPiece?>.of(board);
    b[m.to] = b[m.from];
    b[m.from] = null;
    return XPosition._(b, turn.opposite);
  }

  List<XMove> movesFrom(int from) {
    final p = board[from];
    if (p == null || p.side != turn) return const [];
    return [
      for (final to in _pseudoTargets(from))
        if (!XPosition._(
          List.of(board)
            ..[to] = p
            ..[from] = null,
          turn,
        ).inCheck(turn))
          XMove(from, to),
    ];
  }

  List<XMove> get legalMoves => [
    for (var sq = 0; sq < 90; sq++) ...movesFrom(sq),
  ];
}

enum XOutcome {
  /// Side to move is checkmated.
  checkmate,

  /// Side to move has no legal move but is not in check. Also a loss.
  stalemate,

  /// A side lost by giving perpetual check.
  perpetualCheck,

  /// Position repeated three times with no perpetual check.
  repetition,
}

/// A game with history, undo and outcome.
class XiangqiGame {
  XiangqiGame([XPosition? start]) : _positions = [start ?? XPosition.initial()];

  final List<XPosition> _positions;
  final List<XMove> moves = [];

  XPosition get position => _positions.last;
  XMove? get lastMove => moves.isEmpty ? null : moves.last;

  void play(XMove m) {
    _positions.add(position.play(m));
    moves.add(m);
  }

  bool undo() {
    if (moves.isEmpty) return false;
    moves.removeLast();
    _positions.removeLast();
    return true;
  }

  XOutcome? get outcome {
    final pos = position;
    if (pos.legalMoves.isEmpty) {
      return pos.isCheck ? XOutcome.checkmate : XOutcome.stalemate;
    }
    final rep = _repetition();
    if (rep == null) return null;
    return rep.loser == null ? XOutcome.repetition : XOutcome.perpetualCheck;
  }

  /// Null unless the position has occurred three times. Then the loser is
  /// the side that checked on every one of its moves in the cycle while
  /// the other did not, or null for a draw.
  ({XSide? loser})? _repetition() {
    final key = position.fen;
    final hits = [
      for (var i = 0; i < _positions.length; i++)
        if (_positions[i].fen == key) i,
    ];
    if (hits.length < 3) return null;
    final from = hits.first;
    final checking = {XSide.red: true, XSide.black: true};
    for (var i = from + 1; i < _positions.length; i++) {
      final mover = _positions[i - 1].turn;
      if (!_positions[i].isCheck) checking[mover] = false;
    }
    final red = checking[XSide.red]!, black = checking[XSide.black]!;
    if (red == black) return (loser: null);
    return (loser: red ? XSide.red : XSide.black);
  }

  /// The winner, or null for a draw or a game still in progress.
  XSide? get winner => switch (outcome) {
    XOutcome.checkmate || XOutcome.stalemate => position.turn.opposite,
    XOutcome.perpetualCheck => _repetition()!.loser!.opposite,
    _ => null,
  };
}
