# HeroCard

The one branded card at the top of a main tab, carrying that screen's headline action or number on the green-to-forest gradient.

## Anatomy

- `radius-lg`, clipped. Ground: linear gradient at 135° from `brand-green` to `forest` (72%). Same in both themes.
- AsoOkeStrip across the top edge.
- Body padding `space-5`, gap `space-3`: overline (`overline`, `on-forest-2`), the headline (`rating-xl` in `on-forest`, or in `gold` when it is a rating or reward), a subtitle (`body-sm`, `on-forest-2`), then one action or a row of `forest-raised` tiles.

## Per screen

- Play: "Quick game", the player's last time control ("10 min", "Rapid · rated"), and the gold Play button.
- Puzzles: puzzle rating in gold, streak badge, "Solved today" and "Ready offline" tiles.
- Profile: avatar, display name, membership and streak badges, three rating tiles.
- Tournaments: the next tournament the player joined, its start time, and Join or Open.

## Rules

- One hero per screen, first under the ScreenHeader, inside the screen gutter.
- Gold text on the hero only at 24px or larger (3:1 against `brand-green`); smaller text is `on-forest` or `on-forest-2`.
- No images or bot portraits on the hero.

Flutter: `HeroCard({required Widget child, bool strip = true})` in `lib/core/ui.dart`. The consumer provides the content column.
