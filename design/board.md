# Board

How the chess board looks and behaves everywhere it appears: live games, bot games, puzzles, review, spectating and local tournaments.

## Size and placement

- Game, bot game and spectate screens: the board is the full screen width, edge to edge, with square corners. PlayerBars and the MoveList keep the screen gutter.
- Puzzles and review: the board sits inside the gutter with `radius-board` corners and no card behind it.
- Thumbnails (game history, tournament boards, previews): `radius-board`, no coordinates, no highlights except the last move.
- Never wrap the board in a `Card`. Never add padding inside the board.

## Themes

| Theme | Light squares | Dark squares | Who |
|---|---|---|---|
| Hamduk (default) | `board-light` | `board-dark` | Everyone |
| Classic | `board-classic-light` | `board-classic-dark` | Everyone (the previous board) |
| Adire | `board-adire-light` | `board-adire-dark` | Hamduk Plus |

The board is identical in the light and dark app themes. The player picks a theme in Settings; the choice is stored on the device.

## Pieces

The cburnett set from `assets/pieces/` (MIT via react-chessboard). No other piece set. A dragged piece is drawn 1.2× its square, lifted so its base sits one square above the finger, with `shadow-2`.

## Squares and overlays

Paint in this order, bottom to top:

1. Square colour.
2. `board-last-move` on both squares of the last move.
3. `board-premove` on both squares of a queued premove.
4. `board-selected` on the picked-up piece's square and on a hint square.
5. The `board-check` radial glow under a king in check: solid at the centre, transparent at 70% of the square.
6. Pieces.
7. Legal-move marks for the picked-up piece: a dot 32% of the square in `board-move-dot` on empty squares, a ring with a stroke 8% of the square on captures. No marks while choosing a premove.
8. Arrows (hints, analysis): `board-arrow`, shaft 14% of a square with round caps, head 2.6× the shaft long, stopping at the target square's centre.
9. ReviewBadges on the top-right corner of a destination square in review, overlapping the corner by 4px.

## Coordinates

Inside the board: files along the bottom rank at the bottom-right of each square, ranks along the left file at the top-left. DM Sans 600 at 18% of the square size. A label on a light square uses `board-dark`; on a dark square, `board-light`. They flip with the board. Off in thumbnails.

## Interaction

- Tap a piece, then a square; or drag. Tapping the selected piece again, or an empty square that is not a target, clears the selection.
- Premoves: while it is the opponent's turn you can pick your own piece and any square; it shows in `board-premove` and plays the moment it becomes legal. Tap anywhere on the board to cancel it.
- Promotion: a picker over the promotion square with queen, knight, rook and bishop on `surface` with `shadow-2`; queen first. (The app currently promotes to a queen automatically; replace that with the picker.)
- The last move slides 120ms ease out unless the player dropped the piece by hand. Off in low-data mode and with reduced motion.
- Haptics: a light tick on a legal drop, a heavier one on capture and check.
- Sounds, when on: move, capture, check, game end. Off by default on first install.

## Accessibility

- Each square has a semantics label ("e4, white knight"); a move is announced in words ("Knight takes e5, check").
- Selection, last move and premove are distinguishable without colour: selection lifts the piece by 4%, premove squares carry a small indigo dot in the corner.

## Flutter

`ChessBoardView` in `lib/board/chess_board.dart`. Replace the file-level colour constants (`_light`, `_dark`, `_lastMove`, `_selected`, `_dot`, `_premove`, the arrow colour) with `HcBoardTheme.of(context)`, which returns the squares for the chosen theme and the overlay colours from `HcColors`.
