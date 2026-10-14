# PlayerBar

One row above and one below the board, naming each player with their rating, captured pieces, status and clock.

## Anatomy

- Height `size-player-bar` (52), padding `0 space-4` so it lines up with the screen gutter even when the board is edge to edge.
- Avatar (`size-avatar-md`): a bot shows its portrait on its stage colour; a person shows initials (Avatar).
- Name in `title-sm` (DM Sans, with Noto Sans fallback for names like Adéṣọlá). Never in Playfair.
- Meta line, `body-sm` `ink-2`, tabular: rating with grouping, then captured pieces at 16px overlapping by 5px, then material advantage ("+1") only for the side ahead. Status replaces captures when there is one: "Your move" (`ink-3`), "Reconnecting…" or "Left the game" (`danger-ink`).
- Clock on the right (Clock).

## Rules

- The opponent's bar is above the board and yours below, whichever colour you play.
- Spacing to the board is `space-2`.
- Only the clock repaints every tick.

Flutter: `PlayerBar({required Player player, required int clockMs, required bool toMove, String? status, bool warn = false, List<String> captured = const [], int advantage = 0})`.
