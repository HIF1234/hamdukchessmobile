# Chip

Chips filter or pick one option from a short set, such as puzzle themes or a challenge's time control.

- Height `size-button-sm` (34), `radius-full`, 13px semibold, horizontal padding `space-4`, gap `space-2`.
- Idle: `surface-2` with `ink-2`. Selected: `green-soft` with `green` and a leading 16px check.
- A row of chips scrolls horizontally with the screen gutter as its start padding; it never wraps to a second line on the Puzzles screen.
- Use real labels from the data: "Rated mix", "Mate in 2", "Forks", "Back rank".

Flutter: `ChoiceChip` themed in `theme.dart` (`chipTheme`). The consumer provides the label, `selected` and `onSelected`.
