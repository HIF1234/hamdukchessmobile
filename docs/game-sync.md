# Live game sync: how the app stays correct on bad networks

The server is the only authority on a game. The app shows moves straight away for speed, but
never decides that a move is legal or that a game is over. These rules cover the cases that go
wrong on weak mobile networks.

## Playing a move

1. The player moves. The app checks it's legal locally (instant feedback) and draws it at once
   (optimistic render, well under 150 ms).
2. The app sends `POST /games/{id}/move` with `{ uci, ply }`, where `ply` is the server's
   current ply + 1.
3. The reply decides what stands:
   - `200`: accepted. The response has the server's position; the app replaces its local
     position with it.
   - `200` with `duplicate: true`: this move had already landed (an earlier request's reply was
     lost). Treated exactly like a normal success.
   - `409 stale`: the position moved on (for example the opponent's clock ran out, or the
     opponent resigned). The app takes the move back off the board and reloads the game.
   - `400 rejected` (for example "Not your turn", "Game is not active"): take the move back and
     reload.

## A move whose reply never arrives (ambiguous disconnect)

The app can't know whether the move reached the server. It **retries the same request** with
the same `ply`. The server makes this safe: a move that already landed comes back as
`duplicate: true`, so a move is never applied twice. The board keeps showing the move as
pending (dimmed) until a reply confirms it. If the connection stays down, see Reconnecting.

## Near-simultaneous moves and premoves

- A premove is only sent after the opponent's move arrives, as a normal move with the next ply.
- If the opponent's move and the player's move cross in flight (possible on a lagging
  connection), the server accepts whichever arrives first for that ply. The other gets `409` or
  "Not your turn", and the app reloads and shows the true position.
- The app never plays a move for a ply it hasn't seen the server confirm.

## Reconnecting

On every reconnect (network switch, app back from the background, socket dropped), the app:

1. Reloads the whole game with `GET /games/{id}` before trusting anything it had cached.
2. Retries any move still marked pending, with its original `ply`.
3. Re-subscribes to the game's Realtime updates.

Clocks are shown from the server's times and `serverTime`, never from how long the phone was
disconnected.

## The opponent's connection

The app shows three states, not one:

| State | Meaning |
|---|---|
| Thinking | Connected, their clock is running |
| Disconnected, reconnecting | Their connection dropped; a grace period is running |
| Abandoned | The grace period ran out; the server has decided the result |

Losing on time to a four-second network blip is the fastest way to lose a player, so the
server gives a grace period before treating a disconnect as abandonment.

## Still to build (server)

- Grace period on disconnect, and exposing connection state to the app.
- A heartbeat so the app knows the connection is dead before the board looks frozen.
