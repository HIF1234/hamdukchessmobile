import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/game_feedback.dart';
import '../core/telemetry.dart';
import 'game_state.dart';

/// How the opponent's connection looks from here (spec §2: three states, not one).
enum OpponentPresence { connected, reconnecting, abandoned }

/// Grace period before a disconnected opponent can be claimed. Matches the server
/// (DISCONNECT_GRACE_MS); the server enforces it, this is only for the countdown.
const disconnectGrace = Duration(seconds: 30);

/// One live game. Follows docs/game-sync.md: the server decides everything; moves show
/// instantly and are reconciled; on any reconnect the full game is reloaded first.
class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController({required this.gameId, required this.myId, this.gamesPlayed = -1});

  final String gameId;
  final String myId;

  /// Games this player had finished before this one (-1 if unknown); lets the §10 cohort
  /// (disconnects in the first three games) be picked out in Analytics.
  final int gamesPlayed;

  /// Ticks five times a second for the clocks and countdowns only, so the board isn't
  /// rebuilt on every tick.
  final ValueNotifier<int> ticks = ValueNotifier(0);

  GameState? game;
  PendingMove? pending;

  /// Moves queued during the opponent's turn, played in order on each of this player's
  /// later turns: (from, to, promotion).
  final List<(String, String, String?)> premoveQueue = [];
  static const _maxPremoves = 3;
  String? error;
  String? notice;
  bool rematchOfferedByMe = false;
  bool rematchOfferedByOpponent = false;

  /// Set once a rematch is accepted; the screen navigates to it.
  String? rematchGameId;
  bool connected = true; // our own Realtime link
  /// Round-trip time to the server, for the signal-bars indicator; null before the first
  /// measurement or whenever a ping fails to answer (treated the same as "offline" there).
  int? pingMs;
  Duration serverOffset = Duration.zero;
  OpponentPresence opponentPresence = OpponentPresence.connected;
  DateTime? opponentAwaySince;

  RealtimeChannel? _channel;
  StreamSubscription<List<ConnectivityResult>>? _net;
  Timer? _retry;
  Timer? _tick;
  Timer? _ping;
  DateTime? _disconnectedAt;
  bool _flagSent = false;
  int _lowTimeTickPly = -1;
  bool _readySent = false;
  int _firstMoveCheckTicks = 0;
  bool _disposed = false;

  bool get isWhite => game?.white.id == myId;
  bool get isParticipant => game != null && (myId == game!.white.id || myId == game!.black.id);
  // isParticipant is required here: without it, a spectator (isWhite false, myId matching
  // neither side) would see myTurn as true whenever it's Black's move, since false == false.
  bool get myTurn => isParticipant && game!.active && (game!.whiteToMove == isWhite) && pending == null;
  Player? get opponent => game == null ? null : (isWhite ? game!.black : game!.white);

  /// What the board shows: the optimistic position while a move is on its way.
  String get boardFen => pending?.fenAfter ?? game?.fen ?? '8/8/8/8/8/8/8/8 w - - 0 1';

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    await reload();
    _subscribe();
    _net = Connectivity().onConnectivityChanged.listen((r) {
      final online = !r.contains(ConnectivityResult.none);
      if (online) {
        _onReconnected();
      } else {
        _onDisconnected();
      }
    });
    // Drives the clocks, the opponent countdown and flagging.
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) => _onTick());
    _ping = Timer.periodic(const Duration(seconds: 5), (_) => _measurePing());
    _measurePing();
  }

  /// Round trip to the server, for the signal-bars indicator -- this is how a player
  /// notices their own connection is bad (slow or down), not just the opponent's.
  Future<void> _measurePing() async {
    final before = DateTime.now();
    try {
      await Api.instance.get('/ping');
      if (_disposed) return;
      pingMs = DateTime.now().difference(before).inMilliseconds;
    } on ApiError {
      if (_disposed) return;
      pingMs = null; // no answer: treated the same as "offline" by the indicator
    }
    _notify();
  }

  // ---------------------------------------------------------------- server state

  Future<void> reload() async {
    try {
      final before = DateTime.now();
      final j = await Api.instance.get('/games/$gameId') as Map<String, dynamic>;
      final rtt = DateTime.now().difference(before);
      final server = DateTime.fromMillisecondsSinceEpoch((j['serverTime'] as num).toInt());
      // The server time was measured mid-request; half the round trip is a fair estimate.
      serverOffset = server.difference(before.add(rtt ~/ 2));
      final fresh = GameState.fromApi(j);
      // A pending move that the server now shows as played is confirmed.
      if (pending != null && fresh.ply >= pending!.ply) pending = null;
      if (game == null && fresh.active) GameFeedback.on(GameEvent.gameStart);
      game = fresh;
      error = null;
      _notify();
      _maybePlayPremove();
      _maybeSendReady();
    } on ApiError catch (e) {
      error = e.isNetwork ? null : e.message;
      _notify();
    }
  }

  void _subscribe() {
    final client = Supabase.instance.client;
    _channel = client
        .channel('game:$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: gameId),
          callback: (p) {
            final g = game;
            if (g == null) return;
            final next = g.mergeRow(p.newRecord);
            final wasMine = pending != null && next.ply >= pending!.ply;
            if (wasMine) pending = null;
            if (next.ply > g.ply) _playMoveFeedback(next, mine: wasMine);
            game = next;
            _notify();
            _maybePlayPremove();
            _maybeSendReady();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'game_events',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'game_id', value: gameId),
          callback: (p) => _onGameEvent(p.newRecord),
        )
        .subscribe((status, [err]) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          // Every (re)subscribe: trust nothing cached until the server has been asked.
          _onReconnected();
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          _onDisconnected();
      }
    });
  }

  /// Tells the server the board has actually rendered, once, if we're White at ply 0. This is
  /// what starts the first-move no-show clock -- not game creation -- so a slow connection
  /// gets time to catch up instead of losing the abort race before it's even loaded.
  void _maybeSendReady() {
    if (_readySent) return;
    final g = game;
    if (g == null || !isWhite || g.ply != 0 || !g.active) return;
    _readySent = true;
    Api.instance.post('/games/$gameId/ready').catchError((_) {
      _readySent = false;
    });
  }

  /// Sound + vibration for the move that just landed: whoever made it, and whether it was a
  /// capture, check, castle or checkmate (read off the SAN -- "x" for capture, "+"/"#" for
  /// check/mate, "O-O"/"O-O-O" for castling).
  void _playMoveFeedback(GameState next, {required bool mine}) {
    if (!next.active) {
      GameFeedback.on(GameEvent.gameEnd);
      return;
    }
    final san = next.sanMoves.isEmpty ? '' : next.sanMoves.last;
    GameFeedback.on(eventForSan(san, mine: mine));
  }

  void _onGameEvent(Map<String, dynamic> e) {
    final by = e['by_user'] as String?;
    if (by == null || by == myId) return;
    switch (e['type']) {
      case 'disconnect':
        opponentAwaySince = DateTime.now();
        opponentPresence = OpponentPresence.reconnecting;
      case 'reconnect':
      case 'move':
        opponentAwaySince = null;
        opponentPresence = OpponentPresence.connected;
      case 'rematch_offer':
        rematchOfferedByOpponent = true;
    }
    _notify();
  }

  void _onDisconnected() {
    if (!connected) return;
    connected = false;
    _disconnectedAt = DateTime.now();
    final g = game;
    if (g != null && g.active) Telemetry.gameDisconnected(gameId: gameId, gamesPlayed: gamesPlayed);
    _notify();
  }

  Future<void> _onReconnected() async {
    final wasDown = !connected;
    connected = true;
    if (wasDown && _disconnectedAt != null) {
      Telemetry.gameReconnected(gameId: gameId, awayMs: DateTime.now().difference(_disconnectedAt!).inMilliseconds);
      _disconnectedAt = null;
    }
    await reload();
    if (pending != null) _send();
  }

  // ---------------------------------------------------------------- moves

  /// Called by the board. Returns true if the move was accepted for sending.
  bool play(String from, String to, String? promotion) {
    final g = game;
    if (g == null || !myTurn) return false;
    final m = prepareMove(g, from, to, promotion);
    if (m == null) return false; // illegal here: never sent
    pending = m;
    _notify();
    _send();
    return true;
  }

  void queuePremove(String from, String to, String? promotion) {
    if (game?.active != true || premoveQueue.length >= _maxPremoves) return;
    premoveQueue.add((from, to, promotion));
    _notify();
  }

  void cancelPremove() {
    premoveQueue.clear();
    _notify();
  }

  /// Plays the first queued premove as soon as it's our turn, if it's still legal then;
  /// an illegal one is dropped and the next in the queue is tried, so one stale premove
  /// doesn't block the rest.
  void _maybePlayPremove() {
    if (!myTurn) return;
    var dropped = false;
    while (premoveQueue.isNotEmpty) {
      final p = premoveQueue.removeAt(0);
      if (play(p.$1, p.$2, p.$3)) return; // sent; play() already notified
      dropped = true;
    }
    if (dropped) _notify();
  }

  Future<void> _send() async {
    final m = pending;
    if (m == null) return;
    _retry?.cancel();
    m.attempts++;
    try {
      final res = await Api.instance.post('/games/$gameId/move', {'uci': m.uci, 'ply': m.ply}) as Map;
      if (pending != m) return;
      // Accepted (or a duplicate of one that already landed): adopt the server's position.
      final g = game!;
      game = g.mergeRow({
        'fen': res['fen'],
        'status': res['status'],
        'result': res['result'],
        'ply': m.ply,
      });
      pending = null;
      _notify();
    } on ApiError catch (e) {
      if (pending != m) return;
      if (e.isNetwork) {
        // Ambiguous: it may or may not have landed. Retry the same move and ply; the server
        // makes this safe. Back off up to 8s; a reconnect also triggers a retry.
        final wait = Duration(milliseconds: (500 * (1 << (m.attempts.clamp(1, 5) - 1))).clamp(500, 8000));
        _retry = Timer(wait, _send);
        return;
      }
      // Stale or rejected: take the move back and show the true position.
      pending = null;
      notice = e.code == 'stale' ? 'The position changed. Here is the latest.' : e.message;
      await reload();
    }
  }

  // ---------------------------------------------------------------- clocks & presence

  void _onTick() {
    final g = game;
    if (g == null || !g.active) return;
    // Black polls for White's first-move no-show while waiting on ply 0 -- there's no clock
    // hitting zero yet to key off, so this checks periodically instead (every ~5s: ticks run
    // at 200ms).
    if (isParticipant && !isWhite && g.ply == 0) {
      _firstMoveCheckTicks++;
      if (_firstMoveCheckTicks >= 25) {
        _firstMoveCheckTicks = 0;
        Api.instance.post('/games/$gameId/first-move-timeout').then((_) => reload()).catchError((_) {});
      }
    }
    // Opponent away longer than the grace period: they can be claimed.
    if (opponentAwaySince != null &&
        DateTime.now().difference(opponentAwaySince!) >= disconnectGrace &&
        opponentPresence != OpponentPresence.abandoned) {
      opponentPresence = OpponentPresence.abandoned;
      _notify();
    }
    // The opponent's clock hit zero: ask the server to end it (it decides).
    final (w, b) = displayClocks(g, now: DateTime.now(), serverOffset: serverOffset);
    final oppMs = isWhite ? b : w;
    // A low-time tick once per move for my own clock under 10s -- reset by _lowTimeTickPly
    // tracking the ply it last played at, so it plays again on each new move under 10s.
    final myMs = isWhite ? w : b;
    if (isParticipant && myMs > 0 && myMs < 10000 && _lowTimeTickPly != g.ply) {
      _lowTimeTickPly = g.ply;
      GameFeedback.on(GameEvent.lowTimeTick);
    }
    if (isParticipant && !_flagSent && oppMs <= 0 && g.ply >= 2 && !myTurn) {
      _flagSent = true;
      Api.instance.post('/games/$gameId/flag').then((_) => reload()).catchError((_) {
        _flagSent = false;
      });
    }
    ticks.value++;
  }

  Duration? get opponentAwayFor => opponentAwaySince == null ? null : DateTime.now().difference(opponentAwaySince!);

  // ---------------------------------------------------------------- actions

  Future<void> resign() => _action('/games/$gameId/resign');
  Future<void> offerDraw() => _action('/games/$gameId/draw');
  Future<void> answerDraw(bool accept) => _action('/games/$gameId/draw', {'accept': accept});
  Future<void> abort() => _action('/games/$gameId/abort');
  Future<void> requestTakeback() => _action('/games/$gameId/takeback');
  Future<void> answerTakeback(bool accept) => _action('/games/$gameId/takeback', {'accept': accept});

  /// Offers a rematch, or accepts the opponent's pending offer, swapping colours either way.
  Future<void> offerOrAcceptRematch() async {
    try {
      if (rematchOfferedByOpponent) {
        final r = await Api.instance.post('/games/$gameId/rematch', {'accept': true}) as Map;
        rematchGameId = r['gameId'] as String;
      } else {
        await Api.instance.post('/games/$gameId/rematch');
        rematchOfferedByMe = true;
      }
      _notify();
    } on ApiError catch (e) {
      notice = e.message;
      _notify();
    }
  }

  Future<void> claimAbandoned() async {
    try {
      final r = await Api.instance.post('/games/$gameId/claim') as Map;
      if (r['ended'] != true && r['reason'] == 'grace') {
        notice = 'Not yet. They still have ${((r['remainingMs'] as num) / 1000).ceil()}s to come back.';
      }
      await reload();
    } on ApiError catch (e) {
      notice = e.message;
      _notify();
    }
  }

  Future<void> _action(String path, [Object? body]) async {
    try {
      await Api.instance.post(path, body);
      await reload();
    } on ApiError catch (e) {
      notice = e.message;
      _notify();
    }
  }

  void clearNotice() {
    notice = null;
    _notify();
  }

  // ---------------------------------------------------------------- app lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final g = game;
    if (g == null || !g.active) return;
    if (state == AppLifecycleState.paused) {
      // Starts the opponent's grace countdown; they can't claim before it ends.
      Api.instance.post('/games/$gameId/away').catchError((_) => null);
    } else if (state == AppLifecycleState.resumed) {
      Api.instance.post('/games/$gameId/back').catchError((_) => null);
      _onReconnected();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _tick?.cancel();
    _ping?.cancel();
    _net?.cancel();
    ticks.dispose();
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }
}
