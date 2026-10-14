# Button

Buttons start things; each screen has at most one large button, and the gold Play button is only for starting a game.

## Variants

| Variant | Use for | Fill / label |
|---|---|---|
| `play` | Starting a game: Play, Play 10 min, Play Mama Cass | `gold` / `on-gold`, `shadow-gold` |
| `primary` | The main action that is not starting a game: Rematch, Accept, Join, Download puzzles | `green` / `on-green` |
| `tonal` | A strong second action next to a primary: Review game, Watch | `green-soft` / `green` |
| `outline` | Neutral options: Challenge a friend, Offer draw, Not now | transparent, 1px `line-control` / `ink` |
| `ghost` | Low-emphasis inline actions in banners and dialogs: Decline, Cancel, Hint | transparent / `green` |
| `danger` | Confirming something you cannot undo: Resign (in the confirm sheet), Block | `danger-ink` / `on-danger` |

## Sizes

- `lg`: `size-button-lg` (52) tall, `radius-md`, 16px bold label. The one main action on a screen; usually full width.
- `md` (default): `size-button-md` (44), `radius-md`, 15px semibold.
- `sm`: `size-button-sm` (34), `radius-full`, 13px semibold. Inside cards and banners.

Icons are 20px (18px in `sm`), leading, from `Icons.*_rounded`. Labels are sentence case and say what happens.

## States

Pressed: an 8% overlay of the label colour. Disabled: 38% opacity, no glow, and the label explains why ("Draw offered"). Focus: `focus-ring`.

## Rules

- One gold fill per screen. If a screen has Play, everything else is green or quieter.
- Never put two primaries side by side; pair primary with outline or ghost.
- Resign on the game screen is an icon action (see GameActions); the red `danger` button only appears in the confirm sheet.

## Flutter

Themed in `lib/core/theme.dart`: `FilledButton` = primary, `FilledButton.tonal` = tonal, `OutlinedButton` = outline, `TextButton` = ghost. Use `PlayButton` (gold, glow) and `FilledButton(style: HcButtons.danger(context))` from `lib/core/ui.dart`. Sizes: `HcButtons.large` / `HcButtons.small` style helpers, or `minimumSize` from `HcSize`.
