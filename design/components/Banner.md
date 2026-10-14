# Banner

An inline message inside the content (not a toast) for something the player should know or answer now.

- `radius-md`, padding `space-3 space-4`, gap `space-3`; 20px icon; text in `title-md` with an optional second line in `body-sm` `ink-2`; up to two `sm` buttons.
- Offer (draw offers, challenge received): `green-soft`, `green` icon, Accept (primary) and Decline (ghost).
- Error and connection: `danger-soft`, `danger-ink` icon or spinner.
- Info (offline, low memory, sync): `surface-2`, `ink-2` icon.
- Sits where it applies: on the game screen between the bottom player bar and the actions; on lists at the top.
- Copy says what happened and what still works: "You're offline. Puzzles and bots still work."

Flutter: `HcBanner({required IconData icon, required String text, String? detail, HcBannerTone tone, List<Widget> actions = const []})`. Replaces `_Banner` in `game_screen.dart` and the bare error `Text` widgets.
