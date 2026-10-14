# ScreenHeader

The title at the top of a screen: a large Playfair title on the five main tabs, a compact bar on screens you push to.

## Large (main tabs)

- Padding `space-4` top and start; title in `display-lg` (Playfair 32/36), optional subtitle in `body-sm` `ink-2`.
- Up to two 48px icon buttons on the right in `ink` (Play: notifications with a Count badge, history).
- On `bg`, no fill, no banner. The HeroCard below gives the screen its colour.
- On scroll it collapses into the compact bar (`SliverAppBar.large`).

## Compact (pushed screens)

- `size-header` (56) tall on `bg`; back arrow, title in `title-lg` (DM Sans 20 bold), actions on the right.
- Game screens use the compact bar with the game type as title ("Rapid 10+0 · Rated").

## Replaces

`TabHeader` (the green gradient banner with the checker texture) on every tab.

Flutter: `ScreenHeader({required String title, String? subtitle, List<Widget> actions = const []})` for tabs (or `SliverAppBar.large` themed with `display-lg`), the themed `AppBar` for pushed screens.
