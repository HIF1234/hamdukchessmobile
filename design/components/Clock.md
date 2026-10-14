# Clock

The game clock pill at the end of a PlayerBar.

- 40px tall, at least 96px wide, `radius-xs`, right-aligned digits in `clock` (JetBrains Mono 26/30, 600, tabular).
- Idle: `surface-2` / `ink-2`. To move: `green` / `on-green`. Under 20 seconds and to move: `danger` / `on-danger`, with tenths ("0:09.4"). Flagged: `danger-soft` / `danger-ink`.
- Format: m:ss; under 10 seconds m:ss.t; over an hour h:mm:ss.
- A short haptic tick at 10 seconds. No colour change for the side not to move.

Flutter: `GameClock({required int ms, required bool active})`. Wrap it in the `ValueListenableBuilder` that already drives ticks.
