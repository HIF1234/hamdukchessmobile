import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../board/chess_board.dart';
import '../core/active_game.dart';
import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/keep_screen_on.dart';
import '../core/notification_prompt.dart';
import '../core/report_dialog.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../review/review_screen.dart';
import '../social/conversation_screen.dart';
import 'game_controller.dart';
import 'game_state.dart';
import 'voice_move_sheet.dart';

String _categoryName(String category) => category.isEmpty ? '' : '${category[0].toUpperCase()}${category.substring(1)}';

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
  String? _resultShownFor;
  bool _sheetOpen = false;
  bool _flipped = false;
  int? _lookBackPly;

  @override
  void initState() {
    super.initState();
    KeepScreenOn.push();
    c.start();
    c.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final g = c.game;
    if (g != null && c.isParticipant) {
      if (g.active) {
        ActiveGame.setOnline(widget.gameId);
      } else {
        ActiveGame.clear();
      }
    }
    final n = c.notice;
    if (n != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n)));
      c.clearNotice();
    }
    final rematch = c.rematchGameId;
    if (rematch != null && mounted) {
      c.rematchGameId = null;
      if (_sheetOpen) Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GameScreen(gameId: rematch, myId: widget.myId)),
      );
    }
  }

  @override
  void dispose() {
    KeepScreenOn.pop();
    c.removeListener(_onControllerChanged);
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
          FilledButton(style: HcButtons.danger(ctx), onPressed: () => Navigator.pop(ctx, true), child: const Text('Resign')),
        ],
      ),
    );
    if (ok == true) await c.resign();
  }

  Future<void> _sayMove(GameController c) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoiceMoveSheet(controller: c),
    );
  }

  Future<void> _confirmAbort() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abort this game?'),
        content: const Text('No result is recorded for either player.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep playing')),
          FilledButton(style: HcButtons.danger(ctx), onPressed: () => Navigator.pop(ctx, true), child: const Text('Abort')),
        ],
      ),
    );
    if (ok == true) await c.abort();
  }

  Future<void> _share(GameState g) async {
    final hasPgn = g.pgn != null && g.pgn!.isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Share link'),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('Share PGN'),
              enabled: hasPgn,
              subtitle: hasPgn ? null : const Text('No moves yet'),
              onTap: () => Navigator.pop(ctx, 'pgn'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'pgn' && hasPgn) {
      await SharePlus.instance.share(ShareParams(text: g.pgn!));
    } else if (choice == 'link') {
      await SharePlus.instance.share(
        ShareParams(text: 'Watch my game on Hamduk Chess: https://play.chess.hamduk.com.ng/play/${g.id}'),
      );
    }
  }

  Future<void> _report(GameState g) async {
    final opp = c.opponent;
    if (opp == null) return;
    final filed = await showReportDialog(context, targetType: 'user', targetId: opp.id);
    if (filed && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent. Thank you.')));
  }

  String _resultHeadline(GameState g, bool won) {
    if (g.endReason == 'first_move_timeout' || g.endReason == 'abort') return 'Aborted.';
    if (g.result == 'draw' || g.winnerId == null) return 'Draw.';
    return won ? 'You won.' : 'You lost.';
  }

  String _resultDetail(GameState g, bool won) {
    final opp = g.white.id == widget.myId ? g.black : g.white;
    final moves = (g.sanMoves.length / 2).ceil();
    return switch (g.endReason) {
      'checkmate' => 'By checkmate in $moves moves against ${opp.username}.',
      'stalemate' => 'By stalemate.',
      'draw' => 'By the fifty-move rule or repetition.',
      'agreement' => 'By agreement.',
      'resignation' => won ? '${opp.username} resigned.' : 'By resignation.',
      'flag' => 'On time.',
      'disconnect' => '${opp.username} didn\'t return in time.',
      'first_move_timeout' || 'abort' => 'No first move was made in time.',
      _ => '',
    };
  }

  Future<void> _showResult(GameState g) async {
    if (!mounted) return;
    // Ratings update after the game ends; the row this screen just saw over Realtime still
    // has the pre-game player ratings cached, so refetch for the rating-change display below.
    await c.reload();
    if (!mounted) return;
    g = c.game ?? g;
    final won = g.winnerId == widget.myId;
    final canReview = !g.chess960 && g.sanMoves.length >= 2;
    final myDelta = c.isWhite ? g.whiteRatingDelta : g.blackRatingDelta;
    final me = c.isWhite ? g.white : g.black;
    final ratingBefore = myDelta == null || me.rating == null ? null : me.rating! - myDelta;
    final ratingAfter = myDelta == null ? null : me.rating;
    _sheetOpen = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final hc = ctx.hc;
        return Container(
          decoration: BoxDecoration(color: hc.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(HcRadius.lg))),
          child: ResultSheet(
            overline: 'Game over · ${_categoryName(g.category)} ${g.timeControl}',
            headline: _resultHeadline(g, won),
            detail: _resultDetail(g, won),
            ratingBefore: ratingBefore,
            ratingAfter: ratingAfter,
            actions: [
              if (c.isParticipant)
                ListenableBuilder(
                  listenable: c,
                  builder: (context, _) {
                    final label = c.rematchOfferedByOpponent
                        ? 'Accept rematch'
                        : (c.rematchOfferedByMe ? 'Waiting for opponent…' : 'Rematch');
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: HcButtons.large(),
                        onPressed: c.rematchOfferedByMe && !c.rematchOfferedByOpponent ? null : c.offerOrAcceptRematch,
                        icon: const Icon(Icons.replay_rounded),
                        label: Text(label),
                      ),
                    );
                  },
                ),
              if (canReview)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReviewScreen(
                        startFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                        sanMoves: g.sanMoves,
                        whiteAtBottom: c.isWhite,
                      ),
                    )),
                    child: const Text('Review'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _share(g),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ),
              if (c.isParticipant)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text('New opponent'),
                  ),
                ),
            ],
          ),
        );
      },
    );
    _sheetOpen = false;
    if (mounted) await NotificationPrompt.gameFinished(context);
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final g = c.game;
          return AppBar(
            title: Text(g == null ? 'Game' : '${_categoryName(g.category)} ${g.timeControl} · ${g.rated ? 'Rated' : 'Casual'}'),
            actions: g == null
                ? null
                : [
                    ConnectionSignal(connected: c.connected, pingMs: c.pingMs),
                    const SizedBox(width: HcSpace.s3),
                    PopupMenuButton<String>(
                      onSelected: (choice) {
                        if (choice == 'share') _share(g);
                        if (choice == 'report') _report(g);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'share', child: Text('Share')),
                        if (c.isParticipant) const PopupMenuItem(value: 'report', child: Text('Report opponent')),
                      ],
                    ),
                  ],
          );
        },
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final g = c.game;
            if (g == null) {
              return Center(
                child: c.error != null ? Text(c.error!) : const CircularProgressIndicator(),
              );
            }
            if (!g.active && _resultShownFor != g.id) {
              _resultShownFor = g.id;
              WidgetsBinding.instance.addPostFrameCallback((_) => _showResult(g));
            }
            final me = c.isWhite ? g.white : g.black;
            final opp = c.opponent!;
            final spectating = !c.isParticipant;

            final lastPly = g.sanMoves.length - 1;
            final lookingBack = _lookBackPly != null && _lookBackPly! < lastPly;
            final moveList = MoveListRibbon(
              san: g.sanMoves,
              current: _lookBackPly ?? lastPly,
              onTap: g.sanMoves.isEmpty ? null : (i) => setState(() => _lookBackPly = i == lastPly ? null : i),
            );
            final mat = g.material;
            final opponentBar = PlayerBar(
              name: opp.username,
              rating: opp.rating,
              country: opp.country,
              fideTitle: opp.fideTitle,
              subscriptionTier: opp.subscriptionTier,
              avatar: HcAvatar(name: opp.username),
              status: switch (c.opponentPresence) {
                OpponentPresence.reconnecting => 'Disconnected, reconnecting…',
                OpponentPresence.abandoned => 'Left the game',
                OpponentPresence.connected => g.active && g.whiteToMove != c.isWhite ? 'Thinking…' : null,
              },
              warn: c.opponentPresence != OpponentPresence.connected,
              captured: c.isWhite ? mat.blackCaptured : mat.whiteCaptured,
              advantage: c.isWhite ? (-mat.advantage).clamp(0, 1 << 30) : mat.advantage.clamp(0, 1 << 30),
              clock: _Clock(c: c, white: !c.isWhite),
            );
            final board = ChessBoardView(
              fen: lookingBack ? g.fenAtPly(_lookBackPly!) : c.boardFen,
              whiteAtBottom: c.isWhite != _flipped,
              lastMove: lookingBack
                  ? null
                  : (c.pending != null ? (c.pending!.from, c.pending!.to) : g.lastMove),
              playerColor: c.isWhite ? 'w' : 'b',
              onMove: !lookingBack && g.active ? c.play : null,
              onPremove: !lookingBack && g.active ? c.queuePremove : null,
              onCancelPremove: c.cancelPremove,
              premoveQueue: [for (final p in c.premoveQueue) (p.$1, p.$2)],
              animate: !AppSettings.instance.lowData,
              lastMoveSan: lookingBack || g.sanMoves.isEmpty ? null : g.sanMoves.last,
              confirmMoves: g.isCorrespondence || AppSettings.instance.moveConfirmation,
            );
            final myBar = PlayerBar(
              name: me.username,
              rating: me.rating,
              country: me.country,
              fideTitle: me.fideTitle,
              subscriptionTier: me.subscriptionTier,
              avatar: HcAvatar(name: me.username),
              status: g.active && g.whiteToMove == c.isWhite ? 'Your move' : null,
              captured: c.isWhite ? mat.whiteCaptured : mat.blackCaptured,
              advantage: c.isWhite ? mat.advantage.clamp(0, 1 << 30) : (-mat.advantage).clamp(0, 1 << 30),
              clock: _Clock(c: c, white: c.isWhite),
            );
            final banners = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (lookingBack)
                Padding(
                  padding: const EdgeInsets.only(bottom: HcSpace.s2),
                  child: HcBanner(
                    icon: Icons.history_rounded,
                    text: 'Looking back at move ${_lookBackPly! + 1}',
                    tone: HcBannerTone.offer,
                    actions: [
                      FilledButton(
                        style: HcButtons.small(),
                        onPressed: () => setState(() => _lookBackPly = null),
                        child: const Text('Back to game'),
                      ),
                    ],
                  ),
                ),
              if (c.isParticipant && g.active && g.takebackOfferBy != null && g.takebackOfferBy != widget.myId)
                Padding(
                  padding: const EdgeInsets.only(bottom: HcSpace.s2),
                  child: HcBanner(
                    icon: Icons.undo_rounded,
                    text: '${opp.username} asks for a takeback',
                    tone: HcBannerTone.offer,
                    actions: [
                      FilledButton(style: HcButtons.small(), onPressed: () => c.answerTakeback(true), child: const Text('Accept')),
                      TextButton(style: HcButtons.small(), onPressed: () => c.answerTakeback(false), child: const Text('Decline')),
                    ],
                  ),
                ),
              if (!c.connected)
                Padding(
                  padding: const EdgeInsets.only(bottom: HcSpace.s2),
                  child: HcBanner(icon: Icons.cloud_off_rounded, text: 'Connection lost. Reconnecting…', tone: HcBannerTone.error),
                ),
              if (c.isParticipant && c.opponentPresence == OpponentPresence.abandoned && g.active)
                Padding(
                  padding: const EdgeInsets.only(bottom: HcSpace.s2),
                  child: HcBanner(
                    icon: Icons.person_off_rounded,
                    text: '${opp.username} has been away for over ${disconnectGrace.inSeconds}s.',
                    tone: HcBannerTone.error,
                    actions: [FilledButton(style: HcButtons.small(), onPressed: c.claimAbandoned, child: const Text('Claim the game'))],
                  ),
                ),
              if (c.isParticipant && g.active && g.drawOfferBy != null && g.drawOfferBy != widget.myId)
                Padding(
                  padding: const EdgeInsets.only(bottom: HcSpace.s2),
                  child: HcBanner(
                    icon: Icons.handshake_rounded,
                    text: '${opp.username} offers a draw',
                    tone: HcBannerTone.offer,
                    actions: [
                      FilledButton(style: HcButtons.small(), onPressed: () => c.answerDraw(true), child: const Text('Accept')),
                      TextButton(style: HcButtons.small(), onPressed: () => c.answerDraw(false), child: const Text('Decline')),
                    ],
                  ),
                ),
              if (spectating) Text('Spectating', textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
            ]);

            // Tablets (>=600dp shortest side) get the board on the left, clocks/moves on the
            // right, in either orientation; phones keep the stacked layout, locked to portrait.
            if (MediaQuery.sizeOf(context).shortestSide >= 600) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    opponentBar,
                    Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: board))),
                    myBar,
                  ]),
                ),
                SizedBox(
                  width: 320,
                  child: Column(children: [
                    moveList,
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(HcSpace.s4),
                        child: banners,
                      ),
                    ),
                  ]),
                ),
              ]);
            }
            return Column(
              children: [
                moveList,
                const SizedBox(height: HcSpace.s2),
                opponentBar,
                board,
                myBar,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4, vertical: HcSpace.s3),
                    child: banners,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final g = c.game;
          if (g == null) return const SizedBox.shrink();
          final opp = c.opponent;
          if (c.isParticipant && g.active) {
            final canAbort = g.ply < 6;
            final canTakeback = !g.rated && g.ply > 0;
            return GameActionBar(actions: [
              GameAction(
                icon: Icons.handshake_rounded,
                label: g.drawOfferBy == widget.myId ? 'Draw offered' : 'Offer draw',
                onTap: g.drawOfferBy == widget.myId ? null : c.offerDraw,
              ),
              if (canAbort)
                GameAction(icon: Icons.close_rounded, label: 'Abort', onTap: _confirmAbort)
              else
                GameAction(icon: Icons.flag_rounded, label: 'Resign', onTap: _confirmResign),
              if (canTakeback)
                GameAction(
                  icon: Icons.undo_rounded,
                  label: g.takebackOfferBy == widget.myId ? 'Takeback asked' : 'Takeback',
                  onTap: g.takebackOfferBy != null ? null : c.requestTakeback,
                ),
              GameAction(icon: Icons.swap_vert_rounded, label: 'Flip', onTap: () => setState(() => _flipped = !_flipped)),
              GameAction(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                onTap: opp == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(username: opp.username))),
              ),
              if (AppConfig.current?.feature('voiceMove') ?? true)
                GameAction(icon: Icons.mic_rounded, label: 'Say move', onTap: () => _sayMove(c)),
            ]);
          }
          if (!c.isParticipant) {
            return GameActionBar(actions: [
              GameAction(icon: Icons.swap_vert_rounded, label: 'Flip', onTap: () => setState(() => _flipped = !_flipped)),
              GameAction(icon: Icons.share_rounded, label: 'Share', onTap: () => _share(g)),
            ]);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.c, required this.white});
  final GameController c;
  final bool white;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: c.ticks,
      builder: (context, _, _) {
        final g = c.game!;
        final (w, b) = displayClocks(g, now: DateTime.now(), serverOffset: c.serverOffset);
        final active = g.active && g.whiteToMove == white;
        return GameClock(ms: white ? w : b, active: active);
      },
    );
  }
}
