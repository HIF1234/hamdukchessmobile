import 'dart:async';

import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../profile/subscription_sheet.dart';
import 'puzzle_session.dart';

const _durationSec = 180;

/// Three minutes, as many tactics as you can solve: +1 per solve, a miss just loses that
/// puzzle (no penalty, no run-ending) -- same rules as the website's /puzzles/storm, which
/// this calls the same puzzle_storm_scores table and Redis leaderboards through. Plus/Gold
/// only, same as the website.
class StormScreen extends StatefulWidget {
  const StormScreen({super.key});

  @override
  State<StormScreen> createState() => _StormScreenState();
}

enum _Phase { loading, locked, idle, running, ended }

class _StormScreenState extends State<StormScreen> {
  _Phase _phase = _Phase.loading;
  String? _error;
  List<Puzzle> _puzzles = [];
  int _idx = 0;
  PuzzleSession? _session;
  int _score = 0;
  int _mistakes = 0;
  int _timeLeft = _durationSec;
  Timer? _timer;
  DateTime? _startedAt;
  int? _personalBest;
  Map<String, dynamic>? _result; // from /puzzles/storm/submit, once the run ends
  List<Map<String, dynamic>>? _leaderboard;
  String _leaderboardScope = 'daily';

  @override
  void initState() {
    super.initState();
    _checkTier();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkTier() async {
    try {
      final me = await Api.instance.get('/me') as Map;
      final tier = (me['account'] as Map?)?['tier'] as String? ?? 'free';
      if (!mounted) return;
      if (tier == 'free') {
        setState(() => _phase = _Phase.locked);
        return;
      }
      setState(() => _phase = _Phase.idle);
      _loadStats();
      _loadLeaderboard();
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't check your plan. Try again.");
    }
  }

  Future<void> _loadStats() async {
    try {
      final r = await Api.instance.get('/puzzles/storm/stats') as Map;
      if (mounted) setState(() => _personalBest = (r['best'] as num?)?.toInt());
    } catch (_) {
      // Best-effort; the run itself doesn't depend on this.
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final r = await Api.instance.get('/puzzles/storm/leaderboard', {'scope': _leaderboardScope}) as Map;
      if (mounted) setState(() => _leaderboard = (r['entries'] as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // Best-effort; shown as an empty list.
    }
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/puzzles/storm/stream', {'count': '40'}) as Map;
      final puzzles = (r['puzzles'] as List).map((p) => Puzzle.fromJson((p as Map).cast<String, dynamic>())).toList();
      if (puzzles.isEmpty) {
        if (mounted) setState(() => _error = 'No puzzles available right now. Try again shortly.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _puzzles = puzzles;
        _idx = 0;
        _session = PuzzleSession(puzzles.first);
        _score = 0;
        _mistakes = 0;
        _timeLeft = _durationSec;
        _result = null;
        _phase = _Phase.running;
      });
      _startedAt = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final left = (_durationSec - DateTime.now().difference(_startedAt!).inSeconds).clamp(0, _durationSec);
        setState(() => _timeLeft = left);
        if (left <= 0) _end();
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool _onMove(String from, String to, String? promo) {
    final s = _session;
    if (s == null || _phase != _Phase.running) return false;
    final ok = s.tryMove(from, to, promo);
    if (!ok) return false;
    setState(() {});
    if (s.awaitingReply) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(s.playReply);
        if (s.status != PuzzleStatus.playing) _advance();
      });
    } else if (s.status != PuzzleStatus.playing) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _advance();
      });
    }
    return true;
  }

  void _advance() {
    final s = _session;
    if (s == null || _phase != _Phase.running) return;
    setState(() {
      if (s.status == PuzzleStatus.solved) _score++;
      if (s.status == PuzzleStatus.failed) _mistakes++;
      _idx++;
      if (_idx < _puzzles.length) {
        _session = PuzzleSession(_puzzles[_idx]);
      }
    });
    if (_idx >= _puzzles.length) _end(); // ran out of puzzles before the clock
  }

  Future<void> _end() async {
    if (_phase != _Phase.running) return;
    _timer?.cancel();
    setState(() {
      _timeLeft = 0;
      _phase = _Phase.ended;
    });
    try {
      final r = await Api.instance.post('/puzzles/storm/submit', {
        'score': _score,
        'solved': _score,
        'mistakes': _mistakes,
        'durationSec': _durationSec,
      }) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _result = r;
          _personalBest = (r['personalBest'] as num?)?.toInt();
        });
      }
      _loadLeaderboard();
    } catch (_) {
      // The run still shows its score locally even if the submit didn't land.
    }
  }

  String get _mmss {
    final m = _timeLeft ~/ 60;
    final sec = _timeLeft % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Storm')),
      body: SafeArea(
        top: false,
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.locked => EmptyState(
              icon: Icons.bolt_rounded,
              title: 'Puzzle Storm is Plus / Gold',
              body: 'Three-minute tactical rush, daily and all-time leaderboards.',
              actionLabel: 'See plans',
              actionIcon: Icons.workspace_premium_rounded,
              onAction: () => showSubscriptionSheet(context, 'free'),
            ),
          _Phase.idle => _buildIdle(hc),
          _Phase.running => _buildRunning(hc),
          _Phase.ended => _buildEnded(hc),
        },
      ),
    );
  }

  Widget _buildIdle(HcPalette hc) {
    return ListView(
      padding: const EdgeInsets.all(HcSpace.s4),
      children: [
        Icon(Icons.bolt_rounded, size: 48, color: hc.gold),
        const SizedBox(height: HcSpace.s3),
        Text('Three minutes. Solve as many tactics as you can.', style: HcText.titleMd.copyWith(color: hc.ink), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s1),
        Text('+1 per solve, no penalty for a miss -- just keep moving.', style: HcText.bodySm.copyWith(color: hc.ink2), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s4),
        if (_personalBest != null && _personalBest! > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: HcSpace.s4),
            child: Text('Your best: $_personalBest', textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: HcSpace.s3),
            child: Text(_error!, textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
          ),
        FilledButton(style: HcButtons.large(), onPressed: _start, child: const Text('Start 3-minute storm')),
        const SizedBox(height: HcSpace.s4),
        _buildLeaderboard(hc),
      ],
    );
  }

  Widget _buildRunning(HcPalette hc) {
    final s = _session;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s3, HcSpace.s4, HcSpace.s3),
        child: Row(children: [
          HeroCard.tile(label: 'Time', value: _mmss),
          const SizedBox(width: HcSpace.s2),
          HeroCard.tile(label: 'Score', value: '$_score'),
          const SizedBox(width: HcSpace.s2),
          HeroCard.tile(label: 'Misses', value: '$_mistakes'),
        ]),
      ),
      if (s != null)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(HcRadius.board),
                child: ChessBoardView(
                  key: ValueKey('${s.puzzle.id}:$_idx'),
                  fen: s.fen,
                  whiteAtBottom: s.whiteToSolve,
                  lastMove: s.lastMove,
                  lastMoveSan: s.lastSan,
                  onMove: s.status == PuzzleStatus.playing && !s.awaitingReply ? _onMove : null,
                  animate: !AppSettings.instance.lowData,
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildEnded(HcPalette hc) {
    final rank = _result?['rank'] as Map?;
    return ListView(
      padding: const EdgeInsets.all(HcSpace.s4),
      children: [
        Text('Time!', style: HcText.displayXl.copyWith(color: hc.ink), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s3),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          HeroCard.tile(label: 'Score', value: '$_score'),
          const SizedBox(width: HcSpace.s2),
          HeroCard.tile(label: 'Misses', value: '$_mistakes'),
        ]),
        const SizedBox(height: HcSpace.s3),
        if (_personalBest != null)
          Text('Personal best: $_personalBest', textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
        if (rank != null && rank['daily'] != null)
          Text('#${rank['daily']} today', textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
        const SizedBox(height: HcSpace.s4),
        FilledButton(style: HcButtons.large(), onPressed: () => setState(() => _phase = _Phase.idle), child: const Text('Done')),
        const SizedBox(height: HcSpace.s2),
        OutlinedButton(style: HcButtons.large(), onPressed: _start, child: const Text('Play again')),
        const SizedBox(height: HcSpace.s4),
        _buildLeaderboard(hc),
      ],
    );
  }

  Widget _buildLeaderboard(HcPalette hc) {
    final lb = _leaderboard;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Leaderboard', style: HcText.titleSm.copyWith(color: hc.ink))),
        SegmentedButton(
          segments: const [('daily', 'Today'), ('alltime', 'All-time')],
          selected: _leaderboardScope,
          onSelected: (v) {
            setState(() => _leaderboardScope = v);
            _loadLeaderboard();
          },
        ),
      ]),
      const SizedBox(height: HcSpace.s2),
      if (lb == null)
        const Padding(padding: EdgeInsets.all(HcSpace.s4), child: Center(child: CircularProgressIndicator()))
      else if (lb.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: HcSpace.s3),
          child: Text('No runs yet. Be the first.', style: HcText.bodySm.copyWith(color: hc.ink2)),
        )
      else
        for (final (i, e) in lb.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${i + 1}', style: HcText.bodySm.copyWith(color: hc.ink2))),
              Expanded(child: Text(e['username'] as String, style: HcText.bodySm.copyWith(color: hc.ink))),
              Text('${e['score']}', style: HcText.bodySm.copyWith(color: hc.ink, fontWeight: FontWeight.w700)),
            ]),
          ),
    ]);
  }
}

/// A small two-choice segmented control; no shared widget for this exists yet.
class SegmentedButton extends StatelessWidget {
  const SegmentedButton({super.key, required this.segments, required this.selected, required this.onSelected});
  final List<(String, String)> segments;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return DecoratedBox(
      decoration: BoxDecoration(color: hc.surface2, borderRadius: BorderRadius.circular(HcRadius.sm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (value, label) in segments)
          GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3, vertical: 6),
              decoration: BoxDecoration(
                color: selected == value ? hc.green : null,
                borderRadius: BorderRadius.circular(HcRadius.sm),
              ),
              child: Text(label, style: HcText.bodySm.copyWith(color: selected == value ? hc.onGreen : hc.ink2)),
            ),
          ),
      ]),
    );
  }
}
