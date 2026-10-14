# Badge

A small pill that labels status: membership, streaks, live events, rated games and unread counts.

| Badge | Look | Where |
|---|---|---|
| Plus | `gold-soft` / `gold-ink`, uppercase 11px, `workspace_premium` icon | Hamduk Plus members (₦2,500/mo), locked bots, Plus-only boards |
| Gold | `gold` / `on-gold`, uppercase 11px, `workspace_premium` icon | Hamduk Gold members (₦7,000/mo); the stronger badge for the higher tier |
| Streak | `gold-soft` / `gold-ink`, flame icon, "12 day streak" | Puzzles hero, Profile |
| Live | `danger-soft` / `danger-ink`, 8px `danger` dot, uppercase | Live games, running tournaments |
| Rated / Casual | 1px `line-control` outline, `ink-2` | Challenges, game history |
| Count | `green` / `on-green`, 20px circle | Unread messages and notifications |

Height 24 (count 20), `radius-full`, 12px bold, icon 16px. On a HeroCard use the translucent dark variant with `on-forest` text. Never more than two badges side by side.

Flutter: `HcBadge.plus()`, `HcBadge.gold()`, `HcBadge.streak(days)`, `HcBadge.live()`, `HcBadge.rated(bool)`, `HcBadge.count(n)`; `HeaderBadge` becomes `HcBadge.onHero(...)`.
