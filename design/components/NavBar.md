# NavBar

The five-tab bottom navigation: Puzzles, Play, Tournaments, Social, Profile.

- Height `size-nav` (64) plus the system inset; `surface` with a `line` top hairline; no shadow, no tint.
- Each item: a 56 by 30 pill behind a 24px icon, then a 12px label.
- Selected: pill `green-soft`, icon `green` (filled variant), label `ink` bold. Idle: icon and label `ink-2`, outlined icons.
- Icons: `extension_rounded`, the knight silhouette (cburnett black knight tinted with `ColorFilter.mode(color, BlendMode.srcIn)`), `emoji_events_rounded`, `group_rounded`, `person_rounded`.
- Unread count: a Count badge on the pill's top-right corner.
- Play is the default tab on launch once the player has finished onboarding.

Flutter: `NavigationBar` themed in `theme.dart` (`navigationBarTheme`); the knight is `SvgPicture.asset('assets/pieces/bN.svg', colorFilter: ...)`.
