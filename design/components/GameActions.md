# GameActions

The bar docked at the bottom of the game screen with the four in-game actions.

- `surface` with a top hairline in `line`; four equal columns; each action is a 24px icon over a 12px semibold label in `ink-2`, at least 56px tall.
- Live game: Offer draw (`handshake`), Resign (`flag`), Flip (`swap_vert`), Chat (`chat_bubble`). Bot game: Hint, Take back, Flip, Resign. Spectating: Flip and Share only.
- Resign opens a confirm sheet with the red `danger` button. Offer draw becomes "Draw offered" (disabled) until answered.
- An action that is on (chat open) uses `green`.

Flutter: `GameActionBar({required List<GameAction> actions})` where `GameAction` has an icon, label, `onTap` and `active`.
