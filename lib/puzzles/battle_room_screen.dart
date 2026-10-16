import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'puzzle_session.dart';

const _target = 5;

/// One Puzzle Battle: waiting for an opponent, a 4-second countdown, then the same 20
/// puzzles racing against the clock -- first to 5 solved (or the higher score after 3
/// minutes) wins. Mirrors the website's /puzzles/battle/{id} state machine: same statuses
/// (waiting/active/finished), same Realtime table for the opponent's live score.
class BattleRoomScreen extends StatefulWidget {
  const BattleRoomScreen({super.key, required this.battleId});
  final String battleId;

  @override
  State<BattleRoomScreen> createState() => _BattleRoomScreenState();
}

class _BattleRoomScreenState extends State<BattleRoomScreen> {
  Map<String, dynamic>? _state;
  String? _error;
  bool _loading = true;
  Timer? _clock;
  Timer? _publicRepoll;
  RealtimeChannel? _channel;
  int _serverOffsetMs = 0;
  int _sessionIndex = -1;
  PuzzleSession? _session;
  bool _answering = false;
  String? _flash; // 'right' | 'wrong'

  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _publicRepoll?.cancel();
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }

  int get _nowMs => DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/puzzles/battle/${widget.battleId}') as Map<String, dynamic>;
      _serverOffsetMs = (r['serverNow'] as num).toInt() - DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      setState(() {
        _state = r;
        _loading = false;
        _error = null;
      });
      _syncSessionToIndex();
      _subscribe();
      _maybeRepollPublic();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _subscribe() {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel('puzzle-battle-${widget.battleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'puzzle_battles',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.battleId),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  /// Two players who both opened a public battle at the same moment would otherwise wait
  /// forever for each other; re-running matchmaking lets one of them join the other.
  void _maybeRepollPublic() {
    final st = _state;
    if (st == null) return;
    final b = st['battle'] as Map;
    final waitingPublic = b['status'] == 'waiting' && b['is_private'] != true && st['seated'] == true;
    if (!waitingPublic) {
      _publicRepoll?.cancel();
      return;
    }
    _publicRepoll ??= Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final r = await Api.instance.post('/puzzles/battle/find') as Map;
        final newId = r['battleId'] as String;
        if (newId != widget.battleId && mounted) {
          _publicRepoll?.cancel();
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: newId)));
        }
      } catch (_) {
        // Keep waiting.
      }
    });
  }

  void _syncSessionToIndex() {
    final st = _state;
    if (st == null) return;
    final b = st['battle'] as Map;
    final puzzles = (st['puzzles'] as List).cast<Map>();
    final you = st['you'] as String;
    final myIndex = (you == 'a' ? b['a_index'] : b['b_index']) as int;
    if (_sessionIndex == myIndex) return;
    _sessionIndex = myIndex;
    _session = myIndex < puzzles.length ? PuzzleSession(Puzzle.fromJson(puzzles[myIndex].cast<String, dynamic>())) : null;
  }

  bool _onMove(String from, String to, String? promo) {
    final s = _session;
    if (s == null || s.status != PuzzleStatus.playing) return false;
    final ok = s.tryMove(from, to, promo);
    if (!ok) return false;
    setState(() {});
    if (s.awaitingReply) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(s.playReply);
        if (s.status != PuzzleStatus.playing) _submitAnswer(s);
      });
    } else if (s.status != PuzzleStatus.playing) {
      _submitAnswer(s);
    }
    return true;
  }

  Future<void> _submitAnswer(PuzzleSession s) async {
    if (_answering) return;
    _answering = true;
    final index = _sessionIndex;
    setState(() => _flash = s.status == PuzzleStatus.solved ? 'right' : 'wrong');
    try {
      final r = await Api.instance.post('/puzzles/battle/${widget.battleId}/answer', {
        'index': index,
        'moves': s.myMoves,
      }) as Map;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        final battle = r['battle'] as Map?;
        if (battle != null) (_state!['battle'] as Map).addAll(battle);
        _flash = null;
      });
      _syncSessionToIndex();
    } catch (_) {
      if (mounted) setState(() => _flash = null);
    } finally {
      _answering = false;
    }
  }

  Future<void> _accept() async {
    try {
      await Api.instance.post('/puzzles/battle/${widget.battleId}/join');
      await _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancel() async {
    try {
      await Api.instance.post('/puzzles/battle/${widget.battleId}/cancel');
    } catch (_) {
      // Leaving either way.
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _rematch(bool isPrivate) async {
    try {
      final r = await Api.instance.post(isPrivate ? '/puzzles/battle/create' : '/puzzles/battle/find') as Map;
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: r['battleId'] as String)),
        );
      }
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Battle')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : _buildState(hc),
      ),
    );
  }

  Widget _buildState(HcPalette hc) {
    final st = _state!;
    final b = st['battle'] as Map;
    final seated = st['seated'] as bool;
    final status = b['status'] as String;

    if (status == 'waiting' && !seated) {
      final names = st['names'] as Map;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HcSpace.s6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.sports_kabaddi_rounded, size: 48, color: hc.gold),
            const SizedBox(height: HcSpace.s3),
            Text('${names['a']} challenges you to a Puzzle Battle.', textAlign: TextAlign.center, style: HcText.titleMd.copyWith(color: hc.ink)),
            const SizedBox(height: HcSpace.s4),
            FilledButton(style: HcButtons.large(), onPressed: _accept, child: const Text('Accept')),
          ]),
        ),
      );
    }

    if (status == 'waiting' || status == 'cancelled') {
      final isPrivate = b['is_private'] == true;
      final link = 'https://play.chess.hamduk.com.ng/puzzles/battle/${widget.battleId}';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HcSpace.s6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (status == 'cancelled')
              Text('This battle was cancelled.', style: HcText.bodySm.copyWith(color: hc.ink2))
            else if (isPrivate) ...[
              Text('Send this link to a friend', style: HcText.titleSm.copyWith(color: hc.ink)),
              const SizedBox(height: HcSpace.s2),
              Row(children: [
                Expanded(
                  child: Text(link, style: HcText.bodySm.copyWith(color: hc.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    SharePlus.instance.share(ShareParams(text: link));
                  },
                ),
              ]),
              const SizedBox(height: HcSpace.s2),
              Text('Waiting for them to accept…', style: HcText.bodySm.copyWith(color: hc.ink2)),
            ] else
              Text('Looking for an opponent near your puzzle rating…', style: HcText.bodySm.copyWith(color: hc.ink2)),
            const SizedBox(height: HcSpace.s4),
            TextButton(onPressed: _cancel, child: Text(status == 'waiting' ? 'Cancel' : 'Back')),
          ]),
        ),
      );
    }

    final startedAt = DateTime.parse(b['started_at'] as String);
    final endsAt = DateTime.parse(b['ends_at'] as String);
    final startsIn = ((startedAt.millisecondsSinceEpoch - _nowMs) / 1000).ceil();
    final left = (((endsAt.millisecondsSinceEpoch - _nowMs) / 1000).ceil()).clamp(0, 1 << 30);
    final finished = status == 'finished';
    final you = st['you'] as String;
    final names = st['names'] as Map;
    final myScore = you == 'a' ? b['a_score'] as int : b['b_score'] as int;
    final theirScore = you == 'a' ? b['b_score'] as int : b['a_score'] as int;
    final myName = you == 'a' ? names['a'] as String : (names['b'] as String? ?? 'opponent');
    final theirName = you == 'a' ? (names['b'] as String? ?? 'opponent') : names['a'] as String;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s3, HcSpace.s4, HcSpace.s3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: _ScoreCard(name: myName, score: myScore, you: true)),
          SizedBox(
            width: 72,
            child: Text(
              finished ? '—' : '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: HcText.titleMd.copyWith(color: left <= 30 && !finished ? hc.dangerInk : hc.ink, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: _ScoreCard(name: theirName, score: theirScore, you: false)),
        ]),
      ),
      Expanded(
        child: finished
            ? _buildResult(hc, b, myScore, theirScore)
            : startsIn > 0
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Get ready…', style: HcText.bodySm.copyWith(color: hc.ink2)),
                      const SizedBox(height: HcSpace.s2),
                      Text('$startsIn', style: HcText.displayXl.copyWith(color: hc.green, fontSize: 72)),
                    ]),
                  )
                : _session != null
                    ? _buildPuzzle(hc)
                    : Center(
                        child: Text("You've been through every puzzle. Waiting for the clock…",
                            textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
                      ),
      ),
    ]);
  }

  Widget _buildPuzzle(HcPalette hc) {
    final s = _session!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HcRadius.board),
          child: ChessBoardView(
            key: ValueKey('${widget.battleId}:$_sessionIndex'),
            fen: s.fen,
            whiteAtBottom: s.whiteToSolve,
            lastMove: s.lastMove,
            lastMoveSan: s.lastSan,
            onMove: s.status == PuzzleStatus.playing && !s.awaitingReply ? _onMove : null,
            animate: !AppSettings.instance.lowData,
          ),
        ),
        if (_flash != null)
          Padding(
            padding: const EdgeInsets.only(top: HcSpace.s2),
            child: Text(
              _flash == 'right' ? 'Solved!' : 'Missed it — next puzzle',
              textAlign: TextAlign.center,
              style: HcText.titleSm.copyWith(color: _flash == 'right' ? hc.green : hc.dangerInk),
            ),
          ),
      ],
    );
  }

  Widget _buildResult(HcPalette hc, Map b, int myScore, int theirScore) {
    final won = b['winner'] == Supabase.instance.client.auth.currentUser?.id;
    final drew = b['winner'] == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HcSpace.s6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_rounded, size: 48, color: won ? hc.gold : hc.ink3),
          const SizedBox(height: HcSpace.s3),
          Text(won ? 'You win!' : (drew ? "It's a draw" : 'You lost'), style: HcText.displayXl.copyWith(color: hc.ink, fontSize: 36)),
          const SizedBox(height: HcSpace.s1),
          Text('$myScore–$theirScore', style: HcText.titleMd.copyWith(color: hc.ink2)),
          const SizedBox(height: HcSpace.s4),
          FilledButton(style: HcButtons.large(), onPressed: () => _rematch(b['is_private'] == true), child: const Text('Play again')),
          const SizedBox(height: HcSpace.s2),
          OutlinedButton(style: HcButtons.large(), onPressed: () => Navigator.of(context).pop(), child: const Text('Lobby')),
        ]),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.name, required this.score, required this.you});
  final String name;
  final int score;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: you ? hc.greenSoft : hc.surface2,
        borderRadius: BorderRadius.circular(HcRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: HcText.bodySm.copyWith(color: hc.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            for (var i = 0; i < _target; i++)
              Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i == _target - 1 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: i < score ? hc.green : hc.surface3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
