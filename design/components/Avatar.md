# Avatar

A rounded-square picture of a player: initials for people, the portrait on its stage colour for bots.

- Sizes: `size-avatar-sm` (32, 8px corners), `size-avatar-md` (40, `radius-sm`), `size-avatar-lg` (72, `radius-lg`). Rounded squares, not circles, so avatars never look like legal-move dots.
- Initials: up to two letters in DM Sans bold (Noto Sans covers Ọ, Ṣ), on a tint picked by a stable hash of the user id: `green-soft`/`green`, `gold-soft`/`gold-ink` or `surface-3`/`ink`.
- Bots: portrait multiplied onto the bot's stage colour.
- Online: a 12px `green` dot ringed 2px in `surface`, bottom-right.
- Low-data mode never downloads pictures.

Flutter: `HcAvatar({String? imageUrl, required String name, Color? stage, double size = HcSize.avatarMd, bool online = false})`.
