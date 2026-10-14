# AsoOkeStrip

A thin band of woven stripes in gold, green, ivory and forest: Hamduk's signature, after aso-oke, the Yoruba cloth woven in narrow strips and sewn edge to edge like the files of a board.

## Recipe

A 24px repeat across the width, `size-strip` (6px) tall, read left to right: `forest` 6, `brand-gold` 3, `brand-green` 1, `brand-gold` 2, `forest` 3, `on-forest` (ivory) 1, `brand-green` 5, `on-forest` 1, `forest` 2. The uneven groups are what makes it read as cloth rather than a dashed line. Fixed colours, so it looks the same in both themes.

## Where it goes

- The top edge of a HeroCard (once per screen).
- The splash screen and the sign-in panel.
- The winner's row in a finished tournament.

## Don't

- Use it as a divider between rows or sections, run it vertically, animate it, or put two on one screen.
- Recolour it per screen. It replaces the old checkerboard texture behind `TabHeader`.

Flutter: `AsoOkeStrip({double height = HcSize.strip})`, a `CustomPainter` that draws the nine rects of each 24px repeat with colours from `HcColors` (the exact sequence is `HcStrip.pattern` in `tokens.dart`).
