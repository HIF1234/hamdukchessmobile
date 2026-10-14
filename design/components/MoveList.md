# MoveList

A one-line, horizontally scrolling ribbon of the moves so far, between the top player bar and the app bar on the game screen and under the board in review.

- 40px tall, full width, `surface-2`, padding `0 space-3`.
- Move numbers in `notation` `ink-3`; moves in `notation` `ink` with 3px by 6px padding and `radius-xs`.
- The current move: `green-soft` with `green` 600. It always scrolls into view.
- In review, a ReviewBadge sits after the move it classifies.
- Tapping a move during a live game shows that position read-only until you tap the latest move or the board.

Flutter: `MoveListRibbon({required List<String> san, required int current, ValueChanged<int>? onTap, Map<int, Classification>? marks})`.
