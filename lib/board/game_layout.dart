import 'package:flutter/material.dart';

/// Board beside a side panel on wide screens, above it on tall ones.
/// [top] and [bottom] sit right above and below the board (shogi hands).
class GameLayout extends StatelessWidget {
  const GameLayout({
    super.key,
    required this.board,
    required this.status,
    this.top,
    this.bottom,
    this.panel = const [],
  });

  final Widget board;
  final String status;
  final Widget? top;
  final Widget? bottom;

  /// Extra widgets under the status line.
  final List<Widget> panel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight;
          final side = Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                Text(
                  status,
                  key: const ValueKey('status'),
                  style: text.titleMedium,
                ),
                const SizedBox(height: 8),
                ...panel,
              ],
            ),
          );
          // Leave room for hands when present.
          final extra = (top == null ? 0 : 1) + (bottom == null ? 0 : 1);
          final maxBoard = wide
              ? box.maxHeight * (1 - 0.12 * extra)
              : box.maxWidth;
          final boardBox = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBoard),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [?top, board, ?bottom],
                ),
              ),
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
    );
  }
}
