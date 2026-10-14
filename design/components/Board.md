# Board

The chess board: Hamduk forest-and-ivory squares, cburnett pieces, gold for what just happened, indigo for what is queued.

The full specification (sizes, coordinates, drag, arrows, promotion, sounds and accessibility) is in design/board.md. In short:

- Squares: `board-light` / `board-dark` (Hamduk, default). Options: Classic (`board-classic-*`) and Adire (`board-adire-*`, a Plus perk). The board is identical in light and dark themes.
- Overlays: `board-last-move` on both squares of the last move; `board-selected` on the picked-up piece and on a hint square; `board-premove` on queued premove squares; a radial `board-check` glow under a king in check.
- Legal moves: a `board-move-dot` dot (32% of the square) on empty squares and a ring on captures.
- Coordinates inside the bottom rank and left file, 600 weight at 18% of the square, coloured with the opposite square colour.
- Arrows: `board-arrow`, shaft 14% of a square, stopping short of the target centre.
- Edge-to-edge on game screens (square corners); `radius-board` where it sits inside the gutter (puzzles, previews).

The preview shows the Fried Liver after 7. Qf3+: the black king on f7 is in check, the d5 knight is picked up, and f6 and f4 are its only legal moves.

Flutter: `ChessBoardView` in `lib/board/chess_board.dart`. Read colours from `HcBoardTheme.of(context)` instead of the file-level constants.
