# StatTile

A tile with one rating or count and how it changed, used in a row of three on Profile.

- `surface`, `radius-md`, `shadow-1`, padding `space-4`.
- Label: `overline` in `ink-3` with a 16px category icon in `green`.
- Value: `rating-xl`, tabular, with grouping.
- Change: 13px semibold tabular: a rise in `win` ("+12 this week"), a fall in `loss` ("−6 this week", real minus sign), none in `ink-3`.
- Three per row with `space-3` gaps; on phones under 360dp the value drops to `title-lg`.

Flutter: `StatTile({required String label, required IconData icon, required String value, String? delta, int trend = 0})`.
