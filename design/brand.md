# Hamduk Chess brand book

The Hamduk Chess mobile app (Flutter, Android first, then iOS). It keeps the web platform's anchors (forest green `#1a6b3a`, gold `#f5a623`, Playfair Display and DM Sans) and adds what a phone game needs: a branded board, a game table, persona cards for the Naija bots, dark-first surfaces and one woven signature. Build screens from design/screens.md, the board from design/board.md, and code from design/flutter.md.

## Principles

1. **The board is the hero.** On any screen with a board, the board is the largest thing, full width, and everything around it is quieter.
2. **Green acts, gold rewards.** `green` is what you do: primary buttons, the active tab, links, selection. `gold` is what you earned or the one moment that matters most: Play, the current milestone, a rating gain, Plus. One gold fill per screen.
3. **Personality in content, calm in chrome.** Naija character lives in bot portraits, names, catchphrases and result lines, and in the woven strip. Controls stay plain.
4. **Built for the phones people have.** High contrast for outdoor light, no blur, shadows only in the light theme, and every image optional in low-data mode.
5. **Numbers line up.** Ratings, clocks, prices and move numbers use tabular figures and grouping (1,214; ₦2,500).

## Voice and copy

- Plain, warm English in sentence case everywhere: titles, buttons, tabs ("Find opponent", not "FIND OPPONENT"). Overlines are the only uppercase.
- Speak to the player as "you". Buttons say exactly what happens: "Play 10 min", "Offer draw", "Download puzzles", "Rematch".
- Personality is allowed in bot catchphrases (from `/config`, copied as written), result lines ("You won.", "Draw by repetition.") and streak moments. No emoji in the interface; low-data avatars use initials.
- Errors and offline states say what happened and what still works: "Connection lost. Reconnecting…", "You're offline. Puzzles and bots still work.", "No opponent found yet. Try again in a moment."
- Money in naira with grouping and no kobo: "₦2,500/mo", "₦5,000/hr", "₦1,000 entry". Time controls as data writes them in tiles ("15+10"), as words in buttons ("Play 10 min"), with the category in metadata ("Rapid").
- Real lines from the product to match: "Play offline, no data needed. Bot games don't change your rating." / "Finding a 10+0 opponent…" / "The strongest bots are hidden on this phone to keep it smooth."

## Colour

- **Ground.** `bg` behind every screen; `surface` for cards, sheets, list groups and the nav bar; `surface-2` for wells inside them (time-control tiles, inputs, chips, the idle clock, the move list); `surface-3` only for pressed states and skeletons.
- **Text.** `ink` for primary text and icons, `ink-2` for secondary, `ink-3` for tertiary (never on `surface-3`). Each token's note lists the grounds it passes 4.5:1 on, in both themes.
- **Brand.** `green` with `on-green` for fills and `green-soft` behind green text. `gold` with `on-gold` for fills; gold as text only through `gold-ink`, behind it `gold-soft`. `brand-green` and `brand-gold` are the fixed values for the strip and the cover.
- **Hero.** The HeroCard gradient runs from `brand-green` to `forest` at 135°, with `on-forest` and `on-forest-2` text. It looks the same in both themes. One hero per screen.
- **Results.** `win` (green), `loss` (`danger-ink`), `draw` (`ink-2`), always with the letter W, L or D or the word.
- **Danger.** `danger` for icons, the live dot and the low-time clock; `danger-ink` for text and destructive button fills; `danger-soft` behind them.
- **Board, stages and review.** `board-*`, `stage-*` and `review-*` are fixed colours used only by the Board, PersonaCard and ReviewBadge.
- **Themes.** Dark is the design lead; light is complete. The app follows the system setting. The board, the hero and the strip do not change between themes.
- Never use `Colors.green`, `Colors.red`, `Colors.orange`, `Colors.amber` or a raw hex in a widget. Every colour comes from a token.

## Typography

- **Playfair Display 700** (`display-xl`, `display-lg`, `display-md`) only for fixed copy we write, at 24px and up: tab titles, result headlines, sheet titles. Never for user names, buttons, list rows or anything below 24px. It has no ṣ or Hausa letters, and a small serif reads stiff in a game.
- **DM Sans** for everything else (`title-*`, `body-*`, `label`, `overline`, `rating-*`). DM Sans has no ẹ, ọ, ṣ, ɓ, ɗ, ƙ and no ₦, so **Noto Sans** follows it in every stack and fills those letters; names like Adéṣọlá and prices like ₦2,500 render in one consistent face.
- **JetBrains Mono** only for `clock`, `clock-sm` and `notation`.
- Ratings, clocks, prices and counts turn on tabular figures. Overlines are uppercase with 1.2px tracking. Titles balance across lines; nothing in the interface is justified.
- Support text scaling to 1.3× without clipping: titles wrap, tiles and rows grow.

## Layout and spacing

- A 4-point grid: `space-1` (4) to `space-9` (56). The screen gutter, card padding and gap between cards are `space-4`; related items sit `space-2` or `space-3` apart; sections are `space-7` apart, each introduced by an overline.
- Every tappable thing is at least `size-tap` (48) in both directions.
- Main tabs: ScreenHeader, then one HeroCard, then sections. Pushed screens: a compact app bar, then content.
- Game screens: the board runs edge to edge with no gutter; PlayerBars sit `space-2` above and below it with their content on the gutter line; GameActions dock at the bottom.

## Shape, depth and lines

- Radii by role: `radius-xs` clock and small badges; `radius-sm` chips, inputs and 40px avatars; `radius-md` cards, tiles, list groups and large buttons; `radius-lg` the HeroCard and the top of bottom sheets; `radius-xl` onboarding panels; `radius-full` pills; `radius-board` for a board inside a gutter. Edge-to-edge boards are square.
- Depth: in the light theme `shadow-1` lifts resting cards and `shadow-2` lifts sheets; in the dark theme surfaces step up from `bg` to `surface` to `surface-2` and `shadow-1` is a hairline edge. `shadow-gold` marks the single current thing (the current milestone, the tile being searched, the Play button).
- Lines: `line` for dividers and dark-theme card edges; `line-control` for the borders of controls (3:1). No coloured left-border accents on cards.
- Keyboard and switch focus uses `focus-ring`: a 2px gap in `bg`, then a solid 2px green ring. It passes 3:1 on every surface.

## The woven strip

AsoOkeStrip is the signature: a 6px band of uneven stripes in `forest`, `brand-gold`, `brand-green` and ivory (`on-forest`), after aso-oke, the Yoruba cloth woven in narrow strips and sewn edge to edge like the files of a board. Use it once per screen at most: the top edge of the HeroCard, the splash, the sign-in panel and a tournament winner's row. Never as a divider, never vertical, never animated. It replaces the faint checkerboard behind the old `TabHeader`.

## Iconography

- Material icons, rounded style only: Flutter's `Icons.*_rounded` (outlined weight idle, filled for the selected tab). 24px by default, 20px in buttons, 16 to 18px in chips, badges and tiles.
- Time-control categories: bullet `speed`, blitz `bolt`, rapid `timer`, classical `hourglass_empty`.
- Chess concepts use the pieces themselves: the Play tab is the cburnett black knight as a one-colour silhouette. The cburnett set in `assets/pieces/` is the only piece set.
- No emoji anywhere in the interface.

## Imagery

Bot portraits are illustrations on white. They always sit on their stage colour (`stage-mint`, `stage-sand`, `stage-clay`, `stage-indigo`, by rating band) with a multiply blend, so the white becomes the stage and the card works on dark grounds. Nothing else in the app uses photos or illustrations; empty states use a single icon.

## Motion

- 120ms for press feedback, 200ms for state changes (selecting a tile or chip), 320ms for sheets and page transitions; ease out on enter, ease in on exit. Pieces slide 120ms ease out.
- The searching glow on a TimeControlTile breathes over 1.2s; it is the only looping animation.
- Reduced motion and low-data mode turn off the slide and the glow.

## Accessibility

- Text meets 4.5:1 on the grounds each token's note names, in both themes; large text and icons meet 3:1; control borders use `line-control`.
- State is never colour alone: W, L, D letters; the word "Live" beside the dot; a lock with "Plus"; ReviewBadges beside the move.
- Every board move is announced to screen readers in words ("Knight takes e5, check").

## Performance and low data

- No `BackdropFilter`, no large blurred shadows in the dark theme, one gradient per screen.
- Fonts ship inside the app; nothing is fetched at runtime.
- In low-data mode the app downloads no portraits or avatars and shows initials on the stage colour.
