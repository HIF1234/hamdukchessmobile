# ResultPill

A 22px pill with the result letter and, for rated games, the rating change.

- `radius-full`, 12px bold tabular, padding `0 space-2`.
- Win: `green-soft` / `win`. Loss: `danger-soft` / `loss`. Draw: `surface-2` / `draw`.
- Always the letter (W, L, D) first, so colour is never the only signal. Use a real minus sign (−) for losses.

Flutter: `ResultPill({required String outcome, int? delta})`. Replaces `Colors.green.shade700` text in game history and public profiles.
