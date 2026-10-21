# Chess-Go

Board games app: chess, Go, xiangqi, shogi, gomoku/renju. Flutter UI, native
engines later. Android is the production target; macOS and web are dev and
test targets. Licensed GPL-3.0.

## Status (M1)
- Shared `BoardWidget` (`lib/board/`): square or intersection grid, tap and
  drag, legal-move dots, capture rings, last-move and check marks, slide
  animation, flip.
- Chess rules (`lib/games/chess/chess.dart`): legal moves, castling, en
  passant, promotion, FEN, SAN, checkmate, stalemate, 50-move, threefold,
  insufficient material. Verified by perft on 5 standard positions.
- Local two-player chess screen with undo, flip, new game.

## Run
```sh
flutter pub get
flutter run -d macos     # desktop window, hot reload
flutter run -d chrome    # web
flutter run              # Android emulator or USB device
```

## Test
```sh
flutter test                           # rules + widget tests (VM)
flutter test --platform chrome         # same tests compiled for web
flutter test integration_test -d macos # full app on macOS
flutter test integration_test          # full app on Android device/emulator
```

CI (`.github/workflows/ci.yml`) runs all of the above, uploads a debug APK,
and deploys the web build to GitHub Pages from `main` (enable Pages with
source "GitHub Actions" in repo settings).

## Roadmap
M2 Stockfish (NDK; WASM on web), M3 Go (KataGo, Chinese scoring),
M4 xiangqi + shogi, M5 gomoku/renju, M6 polish and Play release.

## Credits
Chess pieces: cburnett set by Colin M.L. Burnett, GPLv2+.
