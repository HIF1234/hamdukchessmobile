# Building in Flutter

How a coding agent applies this system to `HIF1234/hamdukchessmobile`. Read this before writing or changing any widget.

## Files

| File | What it holds |
|---|---|
| `lib/core/tokens.dart` | Generated from this system's `tokens.json`. `HcPalette.dark` / `HcPalette.light` (themed colours), `HcColors` (fixed colours: brand, forest, board, stages, review), `HcSpace`, `HcRadius`, `HcSize`, `HcText`, `HcMotion`, `HcShadows`, `HcStrip`, `HcBoardThemes`. Never edit by hand. |
| `lib/core/theme.dart` | `buildTheme(Brightness)`: the `ThemeData`, its `ColorScheme`, text theme and component themes, plus the `HcTheme` extension. `context.hc` gives the current palette. |
| `lib/core/hc_widgets.dart` | The new shared widgets named in each component's guidelines. |
| `lib/core/ui.dart` | Existing widgets: `SectionLabel` and `RatingLadder` restyled to these tokens with the same API; `TabHeader`, `StatBadge` and `HeaderBadge` deprecated. |
| `assets/fonts/` | Playfair Display Bold, DM Sans 400/500/600/700, JetBrains Mono 500/600, Noto Sans 400/700, as static TTFs declared in `pubspec.yaml`. |

## Reading tokens

```dart
final hc = context.hc;                       // HcPalette for the current theme
Container(
  padding: const EdgeInsets.all(HcSpace.s4),
  decoration: BoxDecoration(color: hc.surface2, borderRadius: BorderRadius.circular(HcRadius.md)),
  child: Text('Rapid', style: HcText.overline.copyWith(color: hc.ink3)),
);
```

`Theme.of(context).colorScheme` and `textTheme` are also mapped (below), so stock Material widgets pick the system up without extra code.

## Rules

1. Every colour comes from `context.hc`, `HcColors` or the `ColorScheme`. No `Colors.*` (except `Colors.transparent`) and no `Color(0x…)` in feature code.
2. Every text style comes from `textTheme` or `HcText`. Playfair only through `display*` styles, `headlineLarge` and `headlineMedium`, and only for fixed copy at 24px and up; never for names.
3. Spacing from `HcSpace`, radii from `HcRadius`, fixed dimensions from `HcSize`. No other numbers for padding, gaps or corners.
4. Icons are `Icons.*_rounded`. The Play tab uses the knight silhouette.
5. Use the shared widgets instead of hand-building cards from `Container` and `BoxDecoration`, and instead of `Card` + `ListTile`.
6. Check every screen in dark and light, at 1.3× text scale, and on a 360dp-wide phone.
7. Do not add UI packages without checking the licence on pub.dev: no GPL or AGPL.

## ColorScheme mapping

| ColorScheme | Token |
|---|---|
| `primary` / `onPrimary` | `green` / `on-green` |
| `primaryContainer` / `onPrimaryContainer` | `green-soft` / `green` |
| `secondary`, `tertiary` / `onSecondary`, `onTertiary` | `gold` / `on-gold` |
| `secondaryContainer` / `onSecondaryContainer` | `gold-soft` / `gold-ink` |
| `error` / `onError` | `danger-ink` / `on-danger` |
| `errorContainer` / `onErrorContainer` | `danger-soft` / `danger-ink` |
| `surface` / `onSurface` | `surface` / `ink` |
| `surfaceContainerLowest` | `bg` |
| `surfaceContainerLow`, `surfaceContainer` | `surface` |
| `surfaceContainerHigh`, `surfaceContainerHighest` | `surface-2` |
| `onSurfaceVariant` | `ink-2` |
| `outline` / `outlineVariant` | `line-control` / `line` |
| `scaffoldBackgroundColor` | `bg` |

## Text theme mapping

| TextTheme | Style |
|---|---|
| `displayLarge`, `displayMedium`, `displaySmall` | `display-xl`, `display-lg`, `display-md` |
| `headlineLarge`, `headlineMedium` | `display-lg`, `display-md` |
| `headlineSmall`, `titleLarge` | `title-lg` |
| `titleMedium`, `titleSmall` | `title-md`, `title-sm` |
| `bodyLarge`, `bodyMedium`, `bodySmall` | `body-lg`, `body`, `body-sm` |
| `labelLarge` | button label (15/600) |
| `labelMedium`, `labelSmall` | `label`, 11/700 |

## Shared widgets

| Widget | Guideline |
|---|---|
| `ScreenHeader` | ScreenHeader (replaces `TabHeader`) |
| `HeroCard`, `AsoOkeStrip` | HeroCard, AsoOkeStrip |
| `PlayButton`, `HcButtons.danger/large/small` | Button |
| `TimeControlTile` | TimeControlTile |
| `PersonaCard` | PersonaCard |
| `PlayerBar`, `GameClock` | PlayerBar, Clock |
| `MoveListRibbon`, `GameActionBar` | MoveList, GameActions |
| `showResultSheet` | ResultSheet |
| `StatTile`; `RatingLadder` and `SectionLabel` (in `ui.dart`) | StatTile, RatingLadder; section overlines |
| `HcBadge`, `ResultPill`, `ReviewBadge` | Badge, ResultPill, ReviewBadge |
| `HcListGroup`, `HcListRow`, `HcAvatar` | ListRow, Avatar |
| `HcBanner`, `EmptyState` | Banner, EmptyState |

## Migration from the current code

Work in this order; each step leaves the app running.

1. **Fonts.** Add the TTFs and the `fonts:` section to `pubspec.yaml`; stop fetching fonts at runtime (`google_fonts` either removed or `GoogleFonts.config.allowRuntimeFetching = false`).
2. **Foundation.** Add `tokens.dart`, the new `theme.dart` and `hc_widgets.dart`; run `flutter analyze` and `flutter test`. The old names in `theme.dart` (`brandGreen`, `brandGold`, …) stay as deprecated aliases until step 9.
3. **Hard-coded colours.** `chess_board.dart` constants → `HcBoardTheme`; `review_screen.dart` `Colors.red/orange/amber` → `ReviewBadge`; `game_history_screen.dart` and `public_profile_screen.dart` `Colors.green.shade700` → `ResultPill`; `social_screen.dart` `Colors.green` → `hc.green`; `profile_screen.dart` `Colors.orangeAccent` → `HcBadge.streak`; `my_sessions_screen.dart` `Colors.amber` stars → `hc.gold`; `report_dialog.dart` `Colors.red` → `hc.dangerInk`.
4. **Headers.** Replace the six `TabHeader`s with `ScreenHeader` plus that tab's `HeroCard` (design/screens.md). Header icons change from white to `ink`.
5. **Play** as in design/screens.md: hero, four-column time controls, outline pair, PersonaCard carousel, bot sheet.
6. **Game and bot game**: MoveList, PlayerBars with `GameClock`, edge-to-edge board, `HcBanner`s, `GameActionBar`, `showResultSheet`.
7. **Puzzles**: hero, ladder, chips, board in the gutter, result line.
8. **Lists**: every `Card` + `ListTile` becomes `HcListGroup` + `HcListRow`; empty lists get `EmptyState`.
9. **Navigation and clean-up**: rounded icons and the knight; promotion picker; delete `TabHeader`, `StatBadge`, `HeaderBadge` and the deprecated aliases.
