# EmptyState

What a section shows when it has nothing yet: an icon, one line saying what is missing, one line on how to fix it, and one button.

- Centred, max 340px wide, padding `space-8 space-6`.
- 64px `surface-2` circle with a 28px `ink-2` icon; title in `title-md`; body in `body-sm` `ink-2`; one primary `md` button.
- Real examples: Puzzles ("No puzzles downloaded yet"), Game history ("No games yet" with Play), Social ("No friends yet" with Find players), Tournaments ("Nothing scheduled" with Browse).
- No illustrations or bot portraits; no exclamation marks.

Flutter: `EmptyState({required IconData icon, required String title, required String body, String? actionLabel, VoidCallback? onAction})`.
