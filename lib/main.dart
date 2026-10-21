import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'games/chess/chess_screen.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks([
      'cburnett chess pieces',
    ], 'Chess piece images by Colin M.L. Burnett, licensed GPLv2 or later.');
  });
  runApp(const ChessGoApp());
}

class ChessGoApp extends StatelessWidget {
  const ChessGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess-Go',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8B5A2B)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF8B5A2B),
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

class _GameEntry {
  const _GameEntry(this.name, this.subtitle, [this.builder]);
  final String name;
  final String subtitle;
  final WidgetBuilder? builder;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final _games = [
    _GameEntry(
      'Chess',
      'Two players, legal-move hints',
      (_) => const ChessScreen(),
    ),
    const _GameEntry('Go', 'Coming soon'),
    const _GameEntry('Xiangqi', 'Coming soon'),
    const _GameEntry('Shogi', 'Coming soon'),
    const _GameEntry('Gomoku / Renju', 'Coming soon'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess-Go'),
        actions: [
          IconButton(
            tooltip: 'Licenses',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Chess-Go',
              applicationLegalese: 'GPL-3.0. Source code is available.',
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final g in _games)
            ListTile(
              title: Text(g.name),
              subtitle: Text(g.subtitle),
              enabled: g.builder != null,
              trailing: const Icon(Icons.chevron_right),
              onTap: g.builder == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: g.builder!),
                    ),
            ),
        ],
      ),
    );
  }
}
