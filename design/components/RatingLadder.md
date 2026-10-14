# RatingLadder

A horizontal path of rating milestones from 400 to 2,200 with the player's current band lit in gold.

- Track on `surface-2`, `radius-md`; steps 56px apart joined by a 2px line: `green` up to the current band, `line-control` after it.
- Reached: 28px `green` disc with an `on-green` check. Current: 40px `gold` disc, `on-gold` trophy, `shadow-gold`, label in `gold-ink` bold. Locked: 28px `surface` disc ringed in `line-control` with a lock in `ink-3`.
- Labels: 12px semibold tabular with grouping.
- Scrolls so the current band is centred on open. With no rating yet: "Solve a puzzle to start climbing" in `ink-3`.
- Milestones: 400, 600, 800, 1,000, 1,200, 1,400, 1,600, 1,800, 2,000, 2,200.

Flutter: the existing `RatingLadder` in `lib/core/ui.dart`, restyled to these tokens.
