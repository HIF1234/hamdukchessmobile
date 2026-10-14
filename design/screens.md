# Screens

Layout recipes for the app's screens, top to bottom. Gutter `space-4` unless a line says edge to edge; sections `space-7` apart, each with an overline.

## Play (tab)

1. ScreenHeader "Play", subtitle "Find an opponent or train against a bot", actions: notifications (Count badge), history.
2. HeroCard "Quick game": the player's last time control ("10 min", "Rapid · rated") and the gold PlayButton "Play". First launch defaults to 10+0.
3. Overline "Time controls", then the TimeControlTile grid (all eight from `/config`). Searching state as in TimeControlTile, with a ghost "Cancel" under the grid.
4. Two outline buttons side by side, equal width: "Play a friend" (`person_add`, creates a WhatsApp challenge link) and "Watch live" (`visibility`).
5. Overline "Naija bots", one line in `body-sm` `ink-2`: "Play offline, no data needed. Bot games don't change your rating." Then the PersonaCard carousel, easiest first. On low-memory phones one more line: "The strongest bots are hidden on this phone to keep it smooth."
6. A tapped bot opens a bottom sheet: portrait on its stage (96px), name in `display-md`, hometown and rating, the bio, a segmented control White / Random / Black (Random selected), and PlayButton "Play Mama Cass".

## Game (live, pushed)

1. Compact app bar: back, title "Rapid 10+0 · Rated", action: more (share, report).
2. MoveList ribbon, edge to edge.
3. Opponent's PlayerBar.
4. Board, edge to edge.
5. Your PlayerBar.
6. Banners as needed (draw offer, opponent away with "Claim the game", connection lost), in the gutter.
7. GameActions docked at the bottom: Offer draw, Resign, Flip, Chat.
8. When the game ends: ResultSheet over the board; the board keeps the final position and last move.

Spectating uses the same layout with GameActions reduced to Flip and Share, and a Live badge in the app bar.

## Bot game (pushed)

As Game, with the bot's portrait avatar in its PlayerBar and its catchphrase as the status line before the first move. GameActions: Hint, Take back, Flip, Resign. No rating row in the ResultSheet; actions are "Play again", "Review" and "Choose another bot".

## Puzzles (tab)

1. ScreenHeader "Puzzles", subtitle "Rated tactics, solved offline".
2. HeroCard: puzzle rating in gold, streak badge, tiles "Solved today" and "Ready offline".
3. RatingLadder.
4. Theme chips (one row, scrolls): Rated mix, Mate in 1, Mate in 2, Forks, Pins, Skewers, Hanging pieces, Discovered attacks, Back rank, Sacrifices, Deflection, Attacking the king, Mate in 3, Endgames.
5. The board inside the gutter with `radius-board`.
6. Under the board: "White to play · rated 1,432" in `title-md`, then a row: ghost "Hint" (then "Show move"), and after solving or failing, primary "Next puzzle". Results: "Solved." with the rating gain as a gold pill, or "Not quite. The best move was Nxe5." in `ink`.
7. Sync status in `body-sm` `ink-3` at the bottom: "186 ready offline · 3 waiting to upload".
8. No pack yet: EmptyState "No puzzles downloaded yet".

## Profile (tab)

1. ScreenHeader "Profile", actions: settings.
2. HeroCard: avatar (72), display name in `title-lg` `on-forest` (DM Sans, never Playfair), username in `on-forest-2`, badges (Plus, streak), then three `forest-raised` tiles: Rapid, Blitz, Puzzles ratings.
3. StatTiles are for other players' public profiles; on your own profile the hero tiles cover it.
4. Sections: "Recent games" (ListRow group, five rows, "See all"), "Coaching" (sessions), "Membership" (Plus card with the strip and the monthly price "₦2,500/mo").

## Tournaments (tab)

1. ScreenHeader "Tournaments".
2. HeroCard for the next tournament you joined (name, start time, format, entry fee, primary "Open"); if none, the next featured one with "Join".
3. Chips: Upcoming, Live, Finished.
4. ListRow group per day: tournament name, "Swiss · 5 rounds · 10+0", start time, Live badge when running, entry fee ("₦1,000" or "Free") trailing.
5. Detail (pushed): compact bar, a summary card, Join (primary, large) or "Joined" state, then tabs Standings / Pairings / Games. A finished tournament's winner row carries the strip on its top edge.

## Social (tab)

1. ScreenHeader "Social", action: add friend.
2. Search field "Search by username".
3. "Requests" (ListRows with Accept primary-sm and Decline ghost-sm), "Friends" (ListRows with online dots and a Challenge outline-sm), "Messages" (ListRows with the last line and time).
4. Empty: EmptyState "No friends yet" with "Find players".

## Sign-in and onboarding

A `forest` screen: the strip across the top, the wordmark "Hamduk Chess" in `display-lg` (`on-forest`, with "Chess" in `gold`), the line "Africa-first chess", then a `surface` panel (`radius-xl`) with "Continue with Google" (outline) and the terms line in `body-sm`. Onboarding steps use the same panel, one question per step, with the board as the illustration where one is needed.

## Sheets and dialogs

- Bottom sheets for choices (time control, colour, bot, report): `surface`, `radius-lg` top corners, handle, padding `space-5`, title in `display-md`.
- Confirm sheets for things you cannot undo ("Resign this game?") with a red `danger` button and an outline "Keep playing".
- The membership sheet: the strip, "Go further" in `display-md`, then one card per tier: Hamduk Plus, ₦2,500/mo (Unlimited puzzles, Deeper game review, No ads) and Hamduk Gold, ₦7,000/mo (Everything in Plus, Paid tournament entry, Priority support), each with check-icon benefit lines and the price in `rating-md`. The tier the player picks gets a 2px `gold` border; one gold "Upgrade" button; "Not now" ghost.
- No `AlertDialog` for choices; snackbars only for confirmations of something already done ("Link copied").

## Lists (history, notifications, leaderboard, coaches)

Compact app bar, optional chips, then ListRow groups. Leaderboard rows lead with the rank in `rating-md` tabular `ink-3`, the top three ranks in `gold-ink`. Coach rows trail with the rate ("₦5,000/hr") and open a detail screen with a gold-free primary "Book a session".
