# Hamduk Chess design

This app has a design system. **Read this file before writing or changing any UI**, then follow it. The goal is an app that looks like one deliberate product: forest green and gold, the Hamduk board, the woven strip, the Naija bots presented with character, and calm, plain controls.

## Where everything is

| What | Where |
|---|---|
| Brand book: principles, voice, colour, type, layout, motion, accessibility | `design/brand.md` |
| One guideline per component (anatomy, tokens, states, Flutter widget) | `design/components/*.md` |
| Screen layouts, top to bottom | `design/screens.md` |
| Board spec (themes, highlights, coordinates, drag, promotion) | `design/board.md` |
| How to build it in Flutter, and the migration plan | `design/flutter.md` |
| What the screens should look like | `design/mockups/*.png` (dark and light) |
| Token source | `design/tokens.json` → `lib/core/tokens.dart` (generated) |
| Theme | `lib/core/theme.dart` (`buildTheme`, `context.hc`) |
| Shared widgets | `lib/core/hc_widgets.dart`, plus `SectionLabel` and `RatingLadder` in `lib/core/ui.dart` |
| Fonts | `assets/fonts/` (bundled; declared in `pubspec.yaml`) |

The live design system and the screen canvas are private Claude Design artifacts on the repo owner's account ("Hamduk Chess" design system, "Hamduk Chess App Screens" canvas). Everything you need is also in `design/`, so work from these files.

## Before you build a screen

1. Open the mockup for it in `design/mockups/` and the matching section of `design/screens.md`.
2. Read the guideline for every component the screen uses in `design/components/`.
3. Use the shared widget named in that guideline. If one is missing, add it to `hc_widgets.dart` following the guideline, not inline in the screen.

## Rules

1. **Colour only from tokens.** `context.hc` (themed), `HcColors` (fixed) or `Theme.of(context).colorScheme`. No `Colors.*` (except `Colors.transparent`) and no `Color(0x…)` in feature code.
2. **Text only from the type scale.** `Theme.of(context).textTheme` or `HcText`. Playfair (`display*`) only for fixed copy at 24px and up: tab titles, result headlines, sheet titles. Never for user names, buttons or list rows.
3. **Spacing from `HcSpace`, corners from `HcRadius`, sizes from `HcSize`.** No other numbers for padding, gaps or radii.
4. **Green acts, gold rewards.** Green for primary actions, the selected tab and selection. Gold for Play, the current milestone, rating gains and Plus. At most one gold fill per screen (`PlayButton` is the gold button).
5. **The board is the hero.** Edge to edge on game screens; nothing wraps it in a card.
6. **Icons are `Icons.*_rounded`.** The Play tab is the knight (`KnightIcon`). No emoji in the interface.
7. **No hand-built cards.** Use `HeroCard`, `HcListGroup`/`HcListRow`, `StatTile`, `HcBanner`, `EmptyState` instead of `Container` + `BoxDecoration` or `Card` + `ListTile`.
8. **Both themes, real phones.** Check every screen in dark and light, at 1.3× text size, on a 360dp-wide phone, and in low-data mode (no portraits).
9. **Copy:** sentence case, say what the button does ("Play 10 min", "Offer draw"), money as "₦2,500".
10. **Licences:** no GPL or AGPL packages (see README).

## Migration plan

Do it in this order, one step per PR or commit, keeping the app running and `flutter analyze` and `flutter test` green after each:

1. Fonts bundled and `google_fonts` removed (done with this design drop).
2. Foundation: `tokens.dart`, `theme.dart`, `hc_widgets.dart` (done with this design drop).
3. Replace hard-coded colours (list in `design/flutter.md`, step 3).
4. Swap the six `TabHeader`s for `ScreenHeader` + each tab's `HeroCard`.
5. Rebuild Play to match `design/mockups/play-dark.png`.
6. Rebuild the game and bot-game screens to match `game-dark.png` and `game-over-dark.png`.
7. Rebuild Puzzles to match `puzzles-dark.png`.
8. Lists: `HcListGroup`/`HcListRow` everywhere, `EmptyState` for empty lists.
9. Navigation icons and the knight; the promotion picker; delete `TabHeader`, `StatBadge`, `HeaderBadge` and the legacy colour names in `theme.dart`.

## Changing the design

Change the design system first, then the code. If tokens change, replace `design/tokens.json` with the system's `tokens.json` and run `python3 design/tools/tokens_to_dart.py` to regenerate `lib/core/tokens.dart`. Never edit `tokens.dart` by hand.
