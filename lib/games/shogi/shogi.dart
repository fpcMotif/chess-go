// Shogi rules: moves, promotion, hands and drops (with nifu, dead-piece
// and pawn-drop-mate bans), check, mate and repetition. Written from the
// rules.
//
// Squares are 0..80 with index = rank * 9 + file. File 0 is the left
// column and rank 0 the bottom row from sente's view; sente (black) is at
// the bottom and moves first. In shogi notation file 0 is "9" and rank 0
// is "i".

enum SSide {
  sente,
  gote;

  SSide get opposite => this == sente ? gote : sente;
}

enum SRole {
  king('k'),
  rook('r'),
  bishop('b'),
  gold('g'),
  silver('s'),
  knight('n'),
  lance('l'),
  pawn('p'),
  dragon('+r'),
  horse('+b'),
  promotedSilver('+s'),
  promotedKnight('+n'),
  promotedLance('+l'),
  tokin('+p');

  const SRole(this.sfen);
  final String sfen;

  SRole? get promoted => switch (this) {
    rook => dragon,
    bishop => horse,
    silver => promotedSilver,
    knight => promotedKnight,
    lance => promotedLance,
    pawn => tokin,
    _ => null,
  };

  /// Base piece; what a captured piece becomes in hand.
  SRole get unpromoted => switch (this) {
    dragon => rook,
    horse => bishop,
    promotedSilver => silver,
    promotedKnight => knight,
    promotedLance => lance,
    tokin => pawn,
    _ => this,
  };

  bool get isPromoted => unpromoted != this;

  static SRole fromSfen(String s) =>
      SRole.values.firstWhere((r) => r.sfen == s.toLowerCase());
}

/// Pieces that can be held, in display order.
const handRoles = [
  SRole.rook,
  SRole.bishop,
  SRole.gold,
  SRole.silver,
  SRole.knight,
  SRole.lance,
  SRole.pawn,
];

class SPiece {
  const SPiece(this.side, this.role);
  final SSide side;
  final SRole role;

  String get sfen => side == SSide.sente ? role.sfen.toUpperCase() : role.sfen;

  @override
  bool operator ==(Object other) =>
      other is SPiece && other.side == side && other.role == role;

  @override
  int get hashCode => side.index * 16 + role.index;
}

/// A board move (with [from]) or a drop (with [drop]).
class SMove {
  const SMove(this.from, this.to, {this.promote = false}) : drop = null;
  const SMove.drop(SRole this.drop, this.to) : from = null, promote = false;

  final int? from;
  final int to;
  final bool promote;
  final SRole? drop;

  bool get isDrop => drop != null;

  static SMove fromUsi(String s) {
    if (s.length >= 4 && s[1] == '*') {
      return SMove.drop(SRole.fromSfen(s[0]), sParseSquare(s.substring(2, 4)));
    }
    return SMove(
      sParseSquare(s.substring(0, 2)),
      sParseSquare(s.substring(2, 4)),
      promote: s.endsWith('+'),
    );
  }

  /// USI notation, e.g. 7g7f, 8h2b+, P*5e.
  String get usi => isDrop
      ? '${drop!.sfen.toUpperCase()}*${sSquareName(to)}'
      : '${sSquareName(from!)}${sSquareName(to)}${promote ? '+' : ''}';

  @override
  bool operator ==(Object other) =>
      other is SMove &&
      other.from == from &&
      other.to == to &&
      other.promote == promote &&
      other.drop == drop;

  @override
  int get hashCode => Object.hash(from, to, promote, drop);

  @override
  String toString() => usi;
}

int sFile(int sq) => sq % 9;
int sRank(int sq) => sq ~/ 9;
int sSquare(int file, int rank) => rank * 9 + file;

/// USI square name: file 9..1 left to right, rank a..i top to bottom.
String sSquareName(int sq) =>
    '${9 - sFile(sq)}${String.fromCharCode(105 - sRank(sq))}';

int sParseSquare(String s) {
  final f = 9 - (s.codeUnitAt(0) - 48);
  final r = 105 - s.codeUnitAt(1);
  if (s.length != 2 || f < 0 || f > 8 || r < 0 || r > 8) {
    throw FormatException('bad square: $s');
  }
  return sSquare(f, r);
}

const shogiStartSfen =
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1';

// Steps as (file, rank) for sente; gote mirrors the rank.
const _goldSteps = [
  [0, 1], [1, 1], [-1, 1], [1, 0], [-1, 0], [0, -1], //
];
const _silverSteps = [
  [0, 1], [1, 1], [-1, 1], [1, -1], [-1, -1], //
];
const _kingSteps = [
  [0, 1], [1, 1], [-1, 1], [1, 0], [-1, 0], [0, -1], [1, -1], [-1, -1], //
];
const _orth = [
  [1, 0], [-1, 0], [0, 1], [0, -1], //
];
const _diag = [
  [1, 1], [1, -1], [-1, 1], [-1, -1], //
];

/// Immutable shogi position.
class SPosition {
  SPosition._(this.board, this.hands, this.turn);

  final List<SPiece?> board;

  /// Counts of each hand role per side.
  final Map<SSide, Map<SRole, int>> hands;
  final SSide turn;

  factory SPosition.initial() => SPosition.fromSfen(shogiStartSfen);

  factory SPosition.fromSfen(String sfen) {
    final parts = sfen.trim().split(RegExp(r'\s+'));
    final rows = parts[0].split('/');
    if (rows.length != 9) throw FormatException('bad SFEN: $sfen');
    final board = List<SPiece?>.filled(81, null);
    for (var i = 0; i < 9; i++) {
      final rank = 8 - i;
      var file = 0;
      var plus = false;
      for (final ch in rows[i].split('')) {
        final n = int.tryParse(ch);
        if (ch == '+') {
          plus = true;
        } else if (n != null) {
          file += n;
        } else {
          if (file > 8) throw FormatException('bad SFEN: $sfen');
          final side = ch == ch.toUpperCase() ? SSide.sente : SSide.gote;
          board[sSquare(file, rank)] = SPiece(
            side,
            SRole.fromSfen(plus ? '+$ch' : ch),
          );
          plus = false;
          file++;
        }
      }
      if (file != 9) throw FormatException('bad SFEN: $sfen');
    }
    final turn = parts.length > 1 && parts[1] == 'w' ? SSide.gote : SSide.sente;
    final hands = _emptyHands();
    if (parts.length > 2 && parts[2] != '-') {
      var count = 0;
      for (final ch in parts[2].split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          count = count * 10 + n;
        } else {
          final side = ch == ch.toUpperCase() ? SSide.sente : SSide.gote;
          final role = SRole.fromSfen(ch);
          hands[side]![role] = hands[side]![role]! + (count == 0 ? 1 : count);
          count = 0;
        }
      }
    }
    return SPosition._(board, hands, turn);
  }

  static Map<SSide, Map<SRole, int>> _emptyHands() => {
    for (final s in SSide.values) s: {for (final r in handRoles) r: 0},
  };

  /// SFEN without the move number.
  String get sfen {
    final rows = <String>[];
    for (var rank = 8; rank >= 0; rank--) {
      final sb = StringBuffer();
      var empty = 0;
      for (var file = 0; file < 9; file++) {
        final p = board[sSquare(file, rank)];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) sb.write(empty);
          empty = 0;
          sb.write(p.sfen);
        }
      }
      if (empty > 0) sb.write(empty);
      rows.add(sb.toString());
    }
    final hand = StringBuffer();
    for (final side in SSide.values) {
      for (final r in handRoles) {
        final n = hands[side]![r]!;
        if (n == 0) continue;
        if (n > 1) hand.write(n);
        hand.write(side == SSide.sente ? r.sfen.toUpperCase() : r.sfen);
      }
    }
    return '${rows.join('/')} ${turn == SSide.sente ? 'b' : 'w'} '
        '${hand.isEmpty ? '-' : hand}';
  }

  SPiece? operator [](int sq) => board[sq];

  int handCount(SSide side, SRole role) => hands[side]![role] ?? 0;

  static int _fwd(SSide side) => side == SSide.sente ? 1 : -1;

  /// Ranks from the far edge, 0 being the last rank for [side].
  static int _depth(SSide side, int rank) =>
      side == SSide.sente ? 8 - rank : rank;

  static bool inZone(SSide side, int rank) => _depth(side, rank) <= 2;

  /// Whether an unpromoted [role] on [rank] would have no legal move.
  static bool isStuck(SSide side, SRole role, int rank) {
    final d = _depth(side, rank);
    return switch (role) {
      SRole.pawn || SRole.lance => d == 0,
      SRole.knight => d <= 1,
      _ => false,
    };
  }

  /// Squares the piece on [from] attacks or can move to.
  List<int> _targets(int from) {
    final p = board[from];
    if (p == null) return const [];
    final f = sFile(from), r = sRank(from);
    final fw = _fwd(p.side);
    final out = <int>[];
    bool on(int ff, int rr) => ff >= 0 && ff < 9 && rr >= 0 && rr < 9;
    void step(List<List<int>> steps) {
      for (final s in steps) {
        final ff = f + s[0], rr = r + s[1] * fw;
        if (!on(ff, rr)) continue;
        final q = board[sSquare(ff, rr)];
        if (q == null || q.side != p.side) out.add(sSquare(ff, rr));
      }
    }

    void slide(List<List<int>> dirs) {
      for (final d in dirs) {
        var ff = f + d[0], rr = r + d[1] * fw;
        while (on(ff, rr)) {
          final q = board[sSquare(ff, rr)];
          if (q == null || q.side != p.side) out.add(sSquare(ff, rr));
          if (q != null) break;
          ff += d[0];
          rr += d[1] * fw;
        }
      }
    }

    switch (p.role) {
      case SRole.king:
        step(_kingSteps);
      case SRole.gold ||
          SRole.promotedSilver ||
          SRole.promotedKnight ||
          SRole.promotedLance ||
          SRole.tokin:
        step(_goldSteps);
      case SRole.silver:
        step(_silverSteps);
      case SRole.knight:
        step(const [
          [1, 2],
          [-1, 2],
        ]);
      case SRole.lance:
        slide(const [
          [0, 1],
        ]);
      case SRole.pawn:
        step(const [
          [0, 1],
        ]);
      case SRole.rook:
        slide(_orth);
      case SRole.bishop:
        slide(_diag);
      case SRole.dragon:
        slide(_orth);
        step(_diag);
      case SRole.horse:
        slide(_diag);
        step(_orth);
    }
    return out;
  }

  int? kingSquare(SSide side) {
    for (var sq = 0; sq < 81; sq++) {
      final p = board[sq];
      if (p != null && p.side == side && p.role == SRole.king) return sq;
    }
    return null;
  }

  bool inCheck(SSide side) {
    final k = kingSquare(side);
    if (k == null) return false;
    for (var sq = 0; sq < 81; sq++) {
      final p = board[sq];
      if (p != null && p.side != side && _targets(sq).contains(k)) {
        return true;
      }
    }
    return false;
  }

  bool get isCheck => inCheck(turn);

  SPosition play(SMove m) {
    final b = List<SPiece?>.of(board);
    final hands = {for (final e in this.hands.entries) e.key: Map.of(e.value)};
    final mine = hands[turn]!;
    if (m.isDrop) {
      mine[m.drop!] = mine[m.drop!]! - 1;
      b[m.to] = SPiece(turn, m.drop!);
    } else {
      final p = b[m.from!]!;
      final captured = b[m.to];
      if (captured != null && captured.role != SRole.king) {
        final r = captured.role.unpromoted;
        mine[r] = mine[r]! + 1;
      }
      b[m.to] = m.promote ? SPiece(turn, p.role.promoted!) : p;
      b[m.from!] = null;
    }
    return SPosition._(b, hands, turn.opposite);
  }

  /// Moves that may not leave the own king in check.
  List<SMove> _pseudoFrom(int from) {
    final p = board[from];
    if (p == null || p.side != turn) return const [];
    final out = <SMove>[];
    final canPromote = p.role.promoted != null;
    for (final to in _targets(from)) {
      final zone =
          canPromote && (inZone(turn, sRank(from)) || inZone(turn, sRank(to)));
      if (zone) out.add(SMove(from, to, promote: true));
      if (!(zone && isStuck(turn, p.role, sRank(to)))) out.add(SMove(from, to));
    }
    return out;
  }

  bool _isLegal(SMove m) => !play(m).inCheck(turn);

  List<SMove> movesFrom(int from) => [
    for (final m in _pseudoFrom(from))
      if (_isLegal(m)) m,
  ];

  List<SMove> dropsOf(SRole role) {
    if (handCount(turn, role) == 0) return const [];
    final out = <SMove>[];
    for (var sq = 0; sq < 81; sq++) {
      if (board[sq] != null) continue;
      if (isStuck(turn, role, sRank(sq))) continue;
      if (role == SRole.pawn && _hasPawnOnFile(turn, sFile(sq))) continue;
      final m = SMove.drop(role, sq);
      if (!_isLegal(m)) continue;
      if (role == SRole.pawn && _isPawnDropMate(m)) continue;
      out.add(m);
    }
    return out;
  }

  bool _hasPawnOnFile(SSide side, int file) {
    for (var rank = 0; rank < 9; rank++) {
      final p = board[sSquare(file, rank)];
      if (p != null && p.side == side && p.role == SRole.pawn) return true;
    }
    return false;
  }

  /// Uchifuzume: a pawn drop may not give immediate checkmate.
  bool _isPawnDropMate(SMove m) {
    final next = play(m);
    return next.isCheck && !next._hasLegalMove(strict: false);
  }

  /// [strict] also applies the pawn-drop-mate ban; the nested call made
  /// while testing that ban skips it to keep the search one level deep.
  bool _hasLegalMove({bool strict = true}) {
    for (var sq = 0; sq < 81; sq++) {
      if (movesFrom(sq).isNotEmpty) return true;
    }
    for (final r in handRoles) {
      if (handCount(turn, r) == 0) continue;
      for (var sq = 0; sq < 81; sq++) {
        if (board[sq] != null || isStuck(turn, r, sRank(sq))) continue;
        if (r == SRole.pawn && _hasPawnOnFile(turn, sFile(sq))) continue;
        final m = SMove.drop(r, sq);
        if (!_isLegal(m)) continue;
        if (strict && r == SRole.pawn && _isPawnDropMate(m)) continue;
        return true;
      }
    }
    return false;
  }

  bool get hasLegalMove => _hasLegalMove();

  List<SMove> get legalMoves => [
    for (var sq = 0; sq < 81; sq++) ...movesFrom(sq),
    for (final r in handRoles) ...dropsOf(r),
  ];
}

enum SOutcome {
  /// Side to move has no legal move (mate). In shogi this is a loss even
  /// without check.
  checkmate,

  /// Sennichite: the same position four times. A draw, unless one side
  /// checked on every move of the cycle, in which case that side loses.
  repetition,
  perpetualCheck,
}

class ShogiGame {
  ShogiGame([SPosition? start]) : _positions = [start ?? SPosition.initial()];

  final List<SPosition> _positions;
  final List<SMove> moves = [];

  SPosition get position => _positions.last;
  SMove? get lastMove => moves.isEmpty ? null : moves.last;

  void play(SMove m) {
    _positions.add(position.play(m));
    moves.add(m);
  }

  bool undo() {
    if (moves.isEmpty) return false;
    moves.removeLast();
    _positions.removeLast();
    return true;
  }

  SOutcome? get outcome {
    if (!position.hasLegalMove) return SOutcome.checkmate;
    final rep = _repetition();
    if (rep == null) return null;
    return rep.loser == null ? SOutcome.repetition : SOutcome.perpetualCheck;
  }

  ({SSide? loser})? _repetition() {
    final key = position.sfen;
    final hits = [
      for (var i = 0; i < _positions.length; i++)
        if (_positions[i].sfen == key) i,
    ];
    if (hits.length < 4) return null;
    final checking = {SSide.sente: true, SSide.gote: true};
    for (var i = hits.first + 1; i < _positions.length; i++) {
      if (!_positions[i].isCheck) checking[_positions[i - 1].turn] = false;
    }
    final s = checking[SSide.sente]!, g = checking[SSide.gote]!;
    if (s == g) return (loser: null);
    return (loser: s ? SSide.sente : SSide.gote);
  }

  SSide? get winner => switch (outcome) {
    SOutcome.checkmate => position.turn.opposite,
    SOutcome.perpetualCheck => _repetition()!.loser!.opposite,
    _ => null,
  };
}
