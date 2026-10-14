# TimeControlTile

A square-ish tile that starts a seek for one time control; the eight tiles form the grid under the Play hero.

## Anatomy

- Height `size-tc-tile` (80), `radius-md`, `surface-2`, padding 10px.
- Top: the category icon, 18px, `green`: bullet `speed`, blitz `bolt`, rapid `timer`, classical `hourglass_empty`.
- Bottom: the time control as data writes it ("15+10") in 20px bold tabular `ink`, the category below in 12px `ink-2`.

## Grid

Four columns with `space-2` gaps from 360dp wide (two rows for the eight controls: 1+0, 2+1, 3+0, 3+2, 5+0, 10+0, 15+10, 30+0); three columns below 360dp. The list comes from `/config`; never hard-code it.

## States

- Idle; pressed (`surface-3`).
- Searching: 2px `gold` border, `shadow-gold`, a spinner in place of the icon and "Searching" in `gold-ink`. The other tiles drop to 45% opacity and a Cancel ghost button appears under the grid. The glow breathes over 1.2s (off in reduced motion and low-data mode).
- Disabled while offline, with a Banner explaining why.

Flutter: `TimeControlTile({required String id, required String category, bool searching = false, bool dimmed = false, VoidCallback? onTap})`.
