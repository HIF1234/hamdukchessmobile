# ListRow

A tappable row in a grouped list: game history, notifications, players, coaches, tournament standings.

- At least 64px tall, padding `space-3 space-4`, gap `space-3`.
- Leading: Avatar (40) or a 40px icon tile on `surface-2`.
- Text: title in `title-sm` (one line, ellipsis); subtitle in `body-sm` `ink-2` with facts joined by " · ".
- Trailing: a ResultPill, a price ("₦5,000/hr", tabular), or a time in 12px `ink-3`; a chevron only when the row opens a new screen.
- Rows sit in a `surface` group with `radius-md` and `shadow-1`; dividers are `line` hairlines inset to the text (68px).
- Examples are example data.

Flutter: `HcListGroup(children: [...])` with `HcListRow({Widget? leading, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap})`. Replace bare `ListTile` inside `Card` with these.
