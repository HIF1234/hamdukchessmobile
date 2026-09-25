# Hamduk Chess — mobile app

Flutter app for Android and iOS. Backend: the Hamduk Chess platform
(`../hamdukchess`, live at https://play.chess.hamduk.com.ng) through its app API.

## Run

```sh
flutter pub get
flutter run            # a connected Android phone or emulator
flutter test
```

iOS builds need a Mac with Xcode.

## How it fits together

- **API:** `https://play.chess.hamduk.com.ng/api/app/v1`, described at
  [`/api/app/v1/openapi.json`](https://play.chess.hamduk.com.ng/api/app/v1/openapi.json).
  Requests carry the player's Supabase access token as `Authorization: Bearer …`.
- **Start-up:** `GET /config` gives the Supabase URL and key, minimum app version, time
  controls and bot personalities. It's cached on the device so the app starts offline.
- **Live games:** subscribe with Supabase Realtime to the `games` row; moves go through the API.
- **Offline:** puzzle packs (`/puzzles/pack`) are stored on the device; results queue locally
  and upload through `/puzzles/sync` when the phone reconnects (`lib/puzzles/puzzle_store.dart`).

## Code layout

| Path | What |
|---|---|
| `lib/core/` | API client, cached config, on-device JSON storage |
| `lib/board/chess_board.dart` | The board widget (tap or drag, legal-move dots) |
| `lib/puzzles/` | Offline puzzle trainer: session logic, store, screen |
| `lib/auth/`, `lib/profile/` | Sign-in and profile |

## Licences: read before adding a package

This app is not open source, so **no GPL or AGPL packages**. In particular don't add
`dartchess`, `chessground` or `stockfish` from pub.dev; all three are GPL-3.0. Chess rules come
from `chess` (BSD-2-Clause). Before adding a dependency, check its licence on pub.dev.

Running Stockfish on the device is planned. Stockfish is GPL-3.0, so how it's bundled needs a
decision before it's added; see `NOTICE.md`.
