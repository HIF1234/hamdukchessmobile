# TextField

A single-line input with its label above it.

- Label: `label` in `ink-2`, 6px above the field.
- Field: `size-tap` (48) tall, `surface-2` fill, 1px `line-control` border, `radius-sm`, padding `0 space-3`, `body` text in `ink`, placeholder in `ink-3`, optional 20px leading icon in `ink-3`.
- Focus: 2px `green` border. Error: 2px `danger-ink` border and the helper line in `danger-ink` saying how to fix it.
- Helper text: `body-sm` `ink-3`.

Flutter: `TextField` themed by `inputDecorationTheme` in `theme.dart`; pass `labelText` via a separate `Text` above (do not use floating labels).
