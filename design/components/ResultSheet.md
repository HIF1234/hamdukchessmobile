# ResultSheet

The bottom sheet that rises over the board when a game ends.

## Anatomy

- `surface`, top corners `radius-lg`, `shadow-2`, handle (36 by 4, `surface-3`), padding `space-5`, gap `space-4`.
- Overline: "Game over · Rapid 10+0".
- Headline in `display-xl` (Playfair): "You won.", "You lost.", "Draw." Fixed copy only.
- One line on how: "By checkmate in 31 moves against Mama Cass.", "On time.", "By resignation.", "By repetition."
- Rating row on `surface-2`: old → new in `rating-md` tabular, and the change as a pill: a gain in `gold`/`on-gold` ("+8"), the sheet's one gold fill, a loss in `danger-soft`/`danger-ink` ("−6", with a real minus sign), no change in `surface-2`/`ink-2`. Bot and unrated games skip the row.
- Actions: Rematch (primary, large), then Review (tonal) and New opponent (outline). Bot games: Play again, Review, Choose another bot.

## Rules

- The board stays visible above the sheet with the final position and the last move highlighted.
- The gold reward appears only for a rating gain; a loss is never gold.
- Dragging the sheet down leaves the result available from a small "Result" chip over the board.

Flutter: `showResultSheet(context, {required GameResult result, required int? ratingBefore, required int? ratingAfter, ...})`.
