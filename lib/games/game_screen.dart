import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import 'game_controller.dart';
import 'game_state.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.gameId, required this.myId, this.gamesPlayed = -1});
  final String gameId;
  final String myId;
  final int gamesPlayed;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController c =
      GameController(gameId: widget.gameId, myId: widget.myId, gamesPlayed: widget.gamesPlayed);

  @override
  void initState() {
    super.initState();
    c.start();
    c.addListener(_showNotice);
  }

  void _showNotice() {
    final n = c.notice;
    if (n == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n)));
    c.clearNotice();
  }

  @override
  void dispose() {
    c.removeListener(_showNotice);
    c.dispose();
    super.dispose();
  }

  Future<void> _confirmResign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resign this game?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resign')),
        ],
      ),
    );
    if (ok == true) await c.resign();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final g = c.game;
            if (g == null) {
              return Center(
                child: c.error != null ? Text(c.error!) : const CircularProgressIndicator(),
              );
            }
            final me = c.isWhite ? g.white : g.black;
            final opp = c.opponent!;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (!c.connected) const _Banner(text: 'Connection lost. Reconnecting…', warning: true),
                _PlayerRow(controller: c, player: opp, white: !c.isWhite, presence: c.opponentPresence),
                const SizedBox(height: 6),
                ChessBoardView(
                  fen: c.boardFen,
                  whiteAtBottom: c.isWhite,
                  lastMove: c.pending != null ? (c.pending!.from, c.pending!.to) : g.lastMove,
                  onMove: c.myTurn ? c.play : null,
                ),
                const SizedBox(height: 6),
                _PlayerRow(controller: c, player: me, white: c.isWhite, presence: null),
                const SizedBox(height: 8),
                if (c.pending != null) const _Banner(text: 'Sending your move…'),
                if (c.opponentPresence == OpponentPresence.abandoned && g.active)
                  _Banner(
                    text: '${opp.username} has been away for over ${disconnectGrace.inSeconds}s.',
                    action: ('Claim the game', c.claimAbandoned),
                    warning: true,
                  ),
                if (g.active && g.drawOfferBy != null && g.drawOfferBy != widget.myId)
                  _Banner(
                    text: '${opp.username} offers a draw.',
                    action: ('Accept', () => c.answerDraw(true)),
                    secondary: ('Decline', () => c.answerDraw(false)),
                  ),
                if (!g.active) _Result(game: g, myId: widget.myId),
                if (g.active)
                  Row(children: [
                    OutlinedButton(
                      onPressed: g.drawOfferBy == widget.myId ? null : c.offerDraw,
                      child: Text(g.drawOfferBy == widget.myId ? 'Draw offered' : 'Offer draw'),
                    ),
                    const Spacer(),
                    TextButton(onPressed: _confirmResign, child: const Text('Resign')),
                  ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.controller, required this.player, required this.white, required this.presence});
  final GameController controller;
  final Player player;
  final bool white;
  final OpponentPresence? presence;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final g = controller.game!;
    final toMove = g.active && g.whiteToMove == white;
    final status = switch (presence) {
      OpponentPresence.reconnecting => 'Disconnected, reconnecting…',
      OpponentPresence.abandoned => 'Left the game',
      _ => toMove ? 'Thinking…' : null,
    };
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${player.username}${player.rating != null ? ' (${player.rating})' : ''}',
              style: t.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
          if (status != null)
            Text(status,
                style: t.textTheme.bodySmall?.copyWith(
                    color: presence == OpponentPresence.connected || presence == null ? null : t.colorScheme.error)),
        ]),
      ),
      // Only the clock listens to the per-tick updates.
      ValueListenableBuilder<int>(
        valueListenable: controller.ticks,
        builder: (context, _, _) {
          final (w, b) = displayClocks(g, now: DateTime.now(), serverOffset: controller.serverOffset);
          final ms = white ? w : b;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: toMove ? t.colorScheme.primary : t.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(formatClock(ms),
                style: t.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: toMove ? t.colorScheme.onPrimary : null,
                )),
          );
        },
      ),
    ]);
  }
}

String formatClock(int ms) {
  final total = (ms / 1000).floor();
  final m = total ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  if (ms < 10000) return '$m:$s.${(ms % 1000) ~/ 100}';
  return '$m:$s';
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.action, this.secondary, this.warning = false});
  final String text;
  final (String, VoidCallback)? action;
  final (String, VoidCallback)? secondary;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      color: warning ? t.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(child: Text(text)),
          if (secondary != null) TextButton(onPressed: secondary!.$2, child: Text(secondary!.$1)),
          if (action != null) FilledButton(onPressed: action!.$2, child: Text(action!.$1)),
        ]),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.game, required this.myId});
  final GameState game;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final won = game.winnerId == myId;
    final text = game.result == 'draw' || game.winnerId == null
        ? 'Game drawn'
        : won
            ? 'You won'
            : 'You lost';
    final reason = game.endReason == null ? '' : ' · ${game.endReason}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text('$text$reason', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
    );
  }
}
