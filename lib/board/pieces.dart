import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A Go or gomoku stone. [marker] draws a small ring (last move).
class StoneView extends StatelessWidget {
  const StoneView({
    super.key,
    required this.black,
    this.marker = false,
    this.faded = false,
  });

  final bool black;
  final bool marker;

  /// Drawn translucent, e.g. a stone marked dead.
  final bool faded;

  @override
  Widget build(BuildContext context) => Semantics(
    label: black ? 'black stone' : 'white stone',
    child: Opacity(
      opacity: faded ? 0.4 : 1,
      child: CustomPaint(painter: _StonePainter(black, marker)),
    ),
  );
}

class _StonePainter extends CustomPainter {
  _StonePainter(this.black, this.marker);
  final bool black;
  final bool marker;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.47;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: black
              ? const [Color(0xFF5A5A5A), Color(0xFF0A0A0A)]
              : const [Color(0xFFFFFFFF), Color(0xFFCFCFCF)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0x66000000),
    );
    if (marker) {
      canvas.drawCircle(
        c,
        r * 0.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.14
          ..color = black ? Colors.white : Colors.black,
      );
    }
  }

  @override
  bool shouldRepaint(_StonePainter old) =>
      old.black != black || old.marker != marker;
}

/// A round xiangqi piece with its Chinese character.
class XiangqiPieceView extends StatelessWidget {
  const XiangqiPieceView({
    super.key,
    required this.red,
    required this.glyph,
    required this.label,
  });

  final bool red;
  final String glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = red ? const Color(0xFFB71C1C) : const Color(0xFF1B1B1B);
    return Semantics(
      label: label,
      child: LayoutBuilder(
        builder: (context, box) {
          final d = box.biggest.shortestSide * 0.9;
          return Center(
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF7E3B5),
                border: Border.all(color: color, width: d * 0.06),
                boxShadow: const [
                  BoxShadow(blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                glyph,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: color,
                  fontSize: d * 0.55,
                  height: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A pentagonal shogi piece. Gote pieces point down. Promoted pieces
/// show their glyph in red.
class ShogiPieceView extends StatelessWidget {
  const ShogiPieceView({
    super.key,
    required this.gote,
    required this.glyph,
    required this.label,
    this.promoted = false,
  });

  final bool gote;
  final bool promoted;
  final String glyph;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Transform.rotate(
      angle: gote ? math.pi : 0,
      child: CustomPaint(
        painter: _PentagonPainter(),
        child: LayoutBuilder(
          builder: (context, box) => Padding(
            padding: EdgeInsets.only(top: box.maxHeight * 0.18),
            child: Center(
              child: Text(
                glyph,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: box.biggest.shortestSide * 0.48,
                  height: 1,
                  color: promoted ? const Color(0xFFC62828) : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PentagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.8, h * 0.2)
      ..lineTo(w * 0.88, h * 0.94)
      ..lineTo(w * 0.12, h * 0.94)
      ..lineTo(w * 0.2, h * 0.2)
      ..close();
    canvas.drawShadow(path, Colors.black, 1.5, false);
    canvas.drawPath(path, Paint()..color = const Color(0xFFF3D9A4));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF6D4C2A),
    );
  }

  @override
  bool shouldRepaint(_PentagonPainter old) => false;
}
