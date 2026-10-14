# ReviewBadge

A 20px square badge that marks how good a move was in game review.

- `radius-xs`; fill and glyph per class: book `review-book` (`menu_book`), best `review-best` (star), good `review-good` (check), inaccuracy `review-inaccuracy` ("?!"), mistake `review-mistake` ("?"), blunder `review-blunder` ("??"). Glyph colour `on-review`, except `on-review-dark` on inaccuracy and mistake.
- Text glyphs are 11px heavy DM Sans; icon glyphs 14px.
- Shown after the move in the MoveList, beside the move in the review list, and on the top-right corner of the destination square on the board (overlapping by 4px).
- Always next to the move text or label, so the class never depends on colour alone.

Flutter: `ReviewBadge(Classification c)`, replacing the `Colors.red`/`orange`/`amber` in `review_screen.dart`.
