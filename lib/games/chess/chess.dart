// Chess rules: move generation, FEN, SAN, game-end detection.
// Written from the rules; API shape inspired by chess.js (BSD-2).
//
// Squares are 0..63 with a1 = 0, h1 = 7, a8 = 56, h8 = 63.

enum Side {
  white,
  black;

  Side get opposite => this == white ? black : white;
}

enum Role {
  pawn('p'),
  knight('n'),
  bishop('b'),
  rook('r'),
  queen('q'),
  king('k');

  const Role(this.letter);
  final String letter;

  static Role fromLetter(String c) =>
      Role.values.firstWhere((r) => r.letter == c.toLowerCase());
}

class Piece {
  const Piece(this.side, this.role);
  final Side side;
  final Role role;

  String get fenChar =>
      side == Side.white ? role.letter.toUpperCase() : role.letter;

  @override
  bool operator ==(Object other) =>
      other is Piece && other.side == side && other.role == role;

  @override
  int get hashCode => side.index * 8 + role.index;

  @override
  String toString() => fenChar;
}

int fileOf(int sq) => sq & 7;
int rankOf(int sq) => sq >> 3;
int squareAt(int file, int rank) => rank * 8 + file;

String squareName(int sq) =>
    '${String.fromCharCode(97 + fileOf(sq))}${rankOf(sq) + 1}';

int parseSquare(String s) {
  if (s.length != 2) throw FormatException('bad square: $s');
  final f = s.codeUnitAt(0) - 97;
  final r = s.codeUnitAt(1) - 49;
  if (f < 0 || f > 7 || r < 0 || r > 7) {
    throw FormatException('bad square: $s');
  }
  return squareAt(f, r);
}

class Move {
  const Move(this.from, this.to, {this.promotion});
  final int from;
  final int to;
  final Role? promotion;

  /// UCI notation, e.g. e2e4, e7e8q.
  String get uci =>
      '${squareName(from)}${squareName(to)}${promotion?.letter ?? ''}';

  static Move fromUci(String s) => Move(
    parseSquare(s.substring(0, 2)),
    parseSquare(s.substring(2, 4)),
    promotion: s.length > 4 ? Role.fromLetter(s[4]) : null,
  );

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion;

  @override
  int get hashCode => Object.hash(from, to, promotion);

  @override
  String toString() => uci;
}

const _knightSteps = [
  [1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2], //
];
const _kingSteps = [
  [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1], //
];
const _rookDirs = [
  [1, 0], [0, 1], [-1, 0], [0, -1], //
];
const _bishopDirs = [
  [1, 1], [-1, 1], [-1, -1], [1, -1], //
];

const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Castling rights as a bitmask.
abstract final class Castling {
  static const whiteKing = 1;
  static const whiteQueen = 2;
  static const blackKing = 4;
  static const blackQueen = 8;
}

/// Immutable chess position.
class Position {
  Position._(
    this.board,
    this.turn,
    this.castling,
    this.epSquare,
    this.halfmoves,
    this.fullmoves,
  );

  /// 64 squares, a1 first.
  final List<Piece?> board;
  final Side turn;
  final int castling;

  /// Square a pawn can capture onto en passant, or null.
  final int? epSquare;
  final int halfmoves;
  final int fullmoves;

  factory Position.initial() => Position.fromFen(startFen);

  factory Position.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) throw FormatException('bad FEN: $fen');
    final board = List<Piece?>.filled(64, null);
    final rows = parts[0].split('/');
    if (rows.length != 8) throw FormatException('bad FEN board: $fen');
    for (var i = 0; i < 8; i++) {
      final rank = 7 - i;
      var file = 0;
      for (final c in rows[i].split('')) {
        final n = int.tryParse(c);
        if (n != null) {
          file += n;
        } else {
          if (file > 7) throw FormatException('bad FEN row: ${rows[i]}');
          final side = c == c.toUpperCase() ? Side.white : Side.black;
          board[squareAt(file, rank)] = Piece(side, Role.fromLetter(c));
          file++;
        }
      }
      if (file != 8) throw FormatException('bad FEN row: ${rows[i]}');
    }
    final turn = parts[1] == 'b' ? Side.black : Side.white;
    var castling = 0;
    if (parts[2].contains('K')) castling |= Castling.whiteKing;
    if (parts[2].contains('Q')) castling |= Castling.whiteQueen;
    if (parts[2].contains('k')) castling |= Castling.blackKing;
    if (parts[2].contains('q')) castling |= Castling.blackQueen;
    final ep = parts[3] == '-' ? null : parseSquare(parts[3]);
    final half = parts.length > 4 ? int.parse(parts[4]) : 0;
    final full = parts.length > 5 ? int.parse(parts[5]) : 1;
    return Position._(List.unmodifiable(board), turn, castling, ep, half, full);
  }

  String get fen {
    final rows = <String>[];
    for (var rank = 7; rank >= 0; rank--) {
      final sb = StringBuffer();
      var empty = 0;
      for (var file = 0; file < 8; file++) {
        final p = board[squareAt(file, rank)];
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
    var c = '';
    if (castling & Castling.whiteKing != 0) c += 'K';
    if (castling & Castling.whiteQueen != 0) c += 'Q';
    if (castling & Castling.blackKing != 0) c += 'k';
    if (castling & Castling.blackQueen != 0) c += 'q';
    if (c.isEmpty) c = '-';
    final ep = epSquare == null ? '-' : squareName(epSquare!);
    return '${rows.join('/')} ${turn == Side.white ? 'w' : 'b'} $c $ep '
        '$halfmoves $fullmoves';
  }

  /// FEN without move counters, used for repetition detection.
  String get repetitionKey => fen.split(' ').take(4).join(' ');

  Piece? operator [](int sq) => board[sq];

  int? kingSquare(Side side) {
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p != null && p.role == Role.king && p.side == side) return sq;
    }
    return null;
  }

  /// Whether [sq] is attacked by any piece of [by].
  bool isAttacked(int sq, Side by) {
    final f = fileOf(sq), r = rankOf(sq);
    Piece? at(int df, int dr) {
      final nf = f + df, nr = r + dr;
      if (nf < 0 || nf > 7 || nr < 0 || nr > 7) return null;
      return board[squareAt(nf, nr)];
    }

    bool isA(Piece? p, Role role) =>
        p != null && p.side == by && p.role == role;

    final pawnDr = by == Side.white ? -1 : 1;
    if (isA(at(-1, pawnDr), Role.pawn) || isA(at(1, pawnDr), Role.pawn)) {
      return true;
    }
    for (final s in _knightSteps) {
      if (isA(at(s[0], s[1]), Role.knight)) return true;
    }
    for (final s in _kingSteps) {
      if (isA(at(s[0], s[1]), Role.king)) return true;
    }
    bool slide(List<List<int>> dirs, Role a, Role b) {
      for (final d in dirs) {
        var nf = f + d[0], nr = r + d[1];
        while (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) {
          final p = board[squareAt(nf, nr)];
          if (p != null) {
            if (p.side == by && (p.role == a || p.role == b)) return true;
            break;
          }
          nf += d[0];
          nr += d[1];
        }
      }
      return false;
    }

    return slide(_rookDirs, Role.rook, Role.queen) ||
        slide(_bishopDirs, Role.bishop, Role.queen);
  }

  bool get isCheck {
    final k = kingSquare(turn);
    return k != null && isAttacked(k, turn.opposite);
  }

  List<Move> _pseudoLegal() {
    final moves = <Move>[];
    final us = turn, them = turn.opposite;
    for (var from = 0; from < 64; from++) {
      final p = board[from];
      if (p == null || p.side != us) continue;
      final f = fileOf(from), r = rankOf(from);

      void addStep(int df, int dr) {
        final nf = f + df, nr = r + dr;
        if (nf < 0 || nf > 7 || nr < 0 || nr > 7) return;
        final to = squareAt(nf, nr);
        final t = board[to];
        if (t == null || t.side == them) moves.add(Move(from, to));
      }

      void addSlides(List<List<int>> dirs) {
        for (final d in dirs) {
          var nf = f + d[0], nr = r + d[1];
          while (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) {
            final to = squareAt(nf, nr);
            final t = board[to];
            if (t == null) {
              moves.add(Move(from, to));
            } else {
              if (t.side == them) moves.add(Move(from, to));
              break;
            }
            nf += d[0];
            nr += d[1];
          }
        }
      }

      switch (p.role) {
        case Role.pawn:
          final dir = us == Side.white ? 1 : -1;
          final startRank = us == Side.white ? 1 : 6;
          final lastRank = us == Side.white ? 7 : 0;
          void addPawn(int to) {
            if (rankOf(to) == lastRank) {
              for (final role in const [
                Role.queen,
                Role.rook,
                Role.bishop,
                Role.knight,
              ]) {
                moves.add(Move(from, to, promotion: role));
              }
            } else {
              moves.add(Move(from, to));
            }
          }

          final one = from + 8 * dir;
          if (board[one] == null) {
            addPawn(one);
            final two = from + 16 * dir;
            if (r == startRank && board[two] == null) {
              moves.add(Move(from, two));
            }
          }
          for (final df in const [-1, 1]) {
            final nf = f + df;
            if (nf < 0 || nf > 7) continue;
            final to = squareAt(nf, r + dir);
            final t = board[to];
            if ((t != null && t.side == them) || to == epSquare) addPawn(to);
          }
        case Role.knight:
          for (final s in _knightSteps) {
            addStep(s[0], s[1]);
          }
        case Role.bishop:
          addSlides(_bishopDirs);
        case Role.rook:
          addSlides(_rookDirs);
        case Role.queen:
          addSlides(_rookDirs);
          addSlides(_bishopDirs);
        case Role.king:
          for (final s in _kingSteps) {
            addStep(s[0], s[1]);
          }
          _addCastles(from, moves);
      }
    }
    return moves;
  }

  void _addCastles(int kingFrom, List<Move> moves) {
    final us = turn, them = turn.opposite;
    final home = us == Side.white ? 4 : 60;
    if (kingFrom != home) return;
    final kSide = us == Side.white ? Castling.whiteKing : Castling.blackKing;
    final qSide = us == Side.white ? Castling.whiteQueen : Castling.blackQueen;
    if (castling & (kSide | qSide) == 0) return;
    if (isAttacked(home, them)) return;
    final rookPiece = Piece(us, Role.rook);
    if (castling & kSide != 0 &&
        board[home + 3] == rookPiece &&
        board[home + 1] == null &&
        board[home + 2] == null &&
        !isAttacked(home + 1, them) &&
        !isAttacked(home + 2, them)) {
      moves.add(Move(home, home + 2));
    }
    if (castling & qSide != 0 &&
        board[home - 4] == rookPiece &&
        board[home - 1] == null &&
        board[home - 2] == null &&
        board[home - 3] == null &&
        !isAttacked(home - 1, them) &&
        !isAttacked(home - 2, them)) {
      moves.add(Move(home, home - 2));
    }
  }

  List<Move>? _legalCache;

  /// All legal moves for the side to move.
  List<Move> get legalMoves => _legalCache ??= List.unmodifiable(
    _pseudoLegal().where((m) => !_play(m).isSideInCheck(turn)),
  );

  /// Legal moves starting at [from].
  List<Move> movesFrom(int from) =>
      legalMoves.where((m) => m.from == from).toList();

  bool isLegal(Move m) => legalMoves.contains(m);

  bool isSideInCheck(Side side) {
    final k = kingSquare(side);
    return k != null && isAttacked(k, side.opposite);
  }

  bool isCapture(Move m) =>
      board[m.to] != null ||
      (board[m.from]?.role == Role.pawn && m.to == epSquare);

  bool isCastle(Move m) =>
      board[m.from]?.role == Role.king && (m.to - m.from).abs() == 2;

  /// Plays a legal move and returns the new position.
  Position play(Move m) {
    if (!isLegal(m)) throw ArgumentError('illegal move $m in $fen');
    return _play(m);
  }

  Position _play(Move m) {
    final b = List<Piece?>.of(board);
    final p = b[m.from]!;
    final capture = isCapture(m);
    int? ep;
    var c = castling;

    if (p.role == Role.pawn) {
      if (m.to == epSquare) {
        b[m.to + (p.side == Side.white ? -8 : 8)] = null;
      }
      if ((m.to - m.from).abs() == 16) ep = (m.from + m.to) ~/ 2;
    }
    if (p.role == Role.king) {
      if (m.to - m.from == 2) {
        b[m.from + 1] = b[m.from + 3];
        b[m.from + 3] = null;
      } else if (m.from - m.to == 2) {
        b[m.from - 1] = b[m.from - 4];
        b[m.from - 4] = null;
      }
      c &= p.side == Side.white
          ? ~(Castling.whiteKing | Castling.whiteQueen)
          : ~(Castling.blackKing | Castling.blackQueen);
    }
    for (final sq in [m.from, m.to]) {
      if (sq == 0) c &= ~Castling.whiteQueen;
      if (sq == 7) c &= ~Castling.whiteKing;
      if (sq == 56) c &= ~Castling.blackQueen;
      if (sq == 63) c &= ~Castling.blackKing;
    }
    b[m.to] = m.promotion != null ? Piece(p.side, m.promotion!) : p;
    b[m.from] = null;

    return Position._(
      List.unmodifiable(b),
      turn.opposite,
      c,
      ep,
      (p.role == Role.pawn || capture) ? 0 : halfmoves + 1,
      turn == Side.black ? fullmoves + 1 : fullmoves,
    );
  }

  bool get isCheckmate => legalMoves.isEmpty && isCheck;
  bool get isStalemate => legalMoves.isEmpty && !isCheck;

  bool get isInsufficientMaterial {
    final minors = <(Role, int)>[];
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == null || p.role == Role.king) continue;
      if (p.role != Role.bishop && p.role != Role.knight) return false;
      minors.add((p.role, (fileOf(sq) + rankOf(sq)) % 2));
    }
    if (minors.length <= 1) return true;
    // Only bishops, all on the same colour.
    return minors.every((m) => m.$1 == Role.bishop) &&
        minors.map((m) => m.$2).toSet().length == 1;
  }

  /// Standard algebraic notation for a legal move, with +/# suffix.
  String san(Move m) {
    final p = board[m.from]!;
    String s;
    if (isCastle(m)) {
      s = m.to > m.from ? 'O-O' : 'O-O-O';
    } else if (p.role == Role.pawn) {
      s = isCapture(m)
          ? '${squareName(m.from)[0]}x${squareName(m.to)}'
          : squareName(m.to);
      if (m.promotion != null) s += '=${m.promotion!.letter.toUpperCase()}';
    } else {
      final others = legalMoves.where(
        (o) => o.to == m.to && o.from != m.from && board[o.from] == p,
      );
      var dis = '';
      if (others.isNotEmpty) {
        final sameFile = others.any((o) => fileOf(o.from) == fileOf(m.from));
        final sameRank = others.any((o) => rankOf(o.from) == rankOf(m.from));
        if (!sameFile) {
          dis = squareName(m.from)[0];
        } else if (!sameRank) {
          dis = squareName(m.from)[1];
        } else {
          dis = squareName(m.from);
        }
      }
      s =
          '${p.role.letter.toUpperCase()}$dis${isCapture(m) ? 'x' : ''}'
          '${squareName(m.to)}';
    }
    final next = play(m);
    if (next.isCheckmate) {
      s += '#';
    } else if (next.isCheck) {
      s += '+';
    }
    return s;
  }

  /// Parses SAN (tolerates missing +/# and 0-0 castling).
  Move parseSan(String san) {
    final clean = san.replaceAll(RegExp(r'[+#!?]'), '').replaceAll('0', 'O');
    for (final m in legalMoves) {
      if (this.san(m).replaceAll(RegExp(r'[+#]'), '') == clean) return m;
    }
    throw FormatException('illegal SAN "$san" in $fen');
  }

  /// Number of leaf nodes at [depth]; used to verify move generation.
  int perft(int depth) {
    if (depth == 0) return 1;
    final moves = legalMoves;
    if (depth == 1) return moves.length;
    var n = 0;
    for (final m in moves) {
      n += _play(m).perft(depth - 1);
    }
    return n;
  }
}

enum Outcome {
  checkmate,
  stalemate,
  insufficientMaterial,
  fiftyMoves,
  threefold,
}

/// A game: list of positions and moves with undo and draw detection.
class ChessGame {
  ChessGame([Position? start]) : _positions = [start ?? Position.initial()];

  final List<Position> _positions;
  final List<Move> _moves = [];
  final List<String> _sans = [];

  Position get position => _positions.last;
  List<Move> get moves => List.unmodifiable(_moves);
  List<String> get sanHistory => List.unmodifiable(_sans);
  Move? get lastMove => _moves.isEmpty ? null : _moves.last;

  void play(Move m) {
    _sans.add(position.san(m));
    _positions.add(position.play(m));
    _moves.add(m);
  }

  void playSan(String san) => play(position.parseSan(san));

  bool undo() {
    if (_moves.isEmpty) return false;
    _positions.removeLast();
    _moves.removeLast();
    _sans.removeLast();
    return true;
  }

  Outcome? get outcome {
    final p = position;
    if (p.isCheckmate) return Outcome.checkmate;
    if (p.isStalemate) return Outcome.stalemate;
    if (p.isInsufficientMaterial) return Outcome.insufficientMaterial;
    if (p.halfmoves >= 100) return Outcome.fiftyMoves;
    final key = p.repetitionKey;
    if (_positions.where((q) => q.repetitionKey == key).length >= 3) {
      return Outcome.threefold;
    }
    return null;
  }

  /// Winner if the game ended in checkmate.
  Side? get winner =>
      outcome == Outcome.checkmate ? position.turn.opposite : null;
}
