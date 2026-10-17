import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'puzzle_session.dart';

/// No timer: puzzles get progressively harder, the first miss ends the run. Free for
/// everyone (unlike Puzzle Storm). Per spec: "No timer; puzzles get harder until the
/// first miss" -- that's the exact rule, not chess.com's 3-mistake Survival mode.
class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

enum _Phase { loading, idle, running, ended }

class _StreakScreenState extends State<StreakScreen> {
  _Phase _phase = _Phase.loading;
  String? _error;
  List<Puzzle> _puzzles = [];
  int _idx = 0;
  PuzzleSession? _session;
  int? _personalBest;
  int _finalStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final r = await Api.instance.get('/puzzles/streak/stats') as Map;
      if (mounted) {
        setState(() {
          _personalBest = (r['best'] as num?)?.toInt();
          _phase = _Phase.idle;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/puzzles/streak/stream', {'count': '60'}) as Map;
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
        _phase = _Phase.running;
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
        if (s.status == PuzzleStatus.solved) _advance();
        if (s.status == PuzzleStatus.failed) _end();
      });
    } else if (s.status == PuzzleStatus.solved) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _advance();
      });
    } else if (s.status == PuzzleStatus.failed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _end();
      });
    }
    return true;
  }

  void _advance() {
    if (_phase != _Phase.running) return;
    setState(() {
      _idx++;
      if (_idx < _puzzles.length) {
        _session = PuzzleSession(_puzzles[_idx]);
      }
    });
    if (_idx >= _puzzles.length) _end(); // ran out of harder puzzles to offer
  }

  Future<void> _end() async {
    if (_phase != _Phase.running) return;
    final streak = _idx; // puzzles solved before the miss (or before running out)
    setState(() {
      _finalStreak = streak;
      _phase = _Phase.ended;
    });
    try {
      final r = await Api.instance.post('/puzzles/streak/submit', {'streak': streak}) as Map<String, dynamic>;
      if (mounted) setState(() => _personalBest = (r['personalBest'] as num?)?.toInt());
    } catch (_) {
      // The run still shows its streak locally even if the submit didn't land.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Streak')),
      body: SafeArea(
        top: false,
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
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
        Icon(Icons.trending_up_rounded, size: 48, color: hc.gold),
        const SizedBox(height: HcSpace.s3),
        Text('No clock. Puzzles get harder each time.', style: HcText.titleMd.copyWith(color: hc.ink), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s1),
        Text('One miss ends the run -- how far can you go?', style: HcText.bodySm.copyWith(color: hc.ink2), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s4),
        if (_personalBest != null && _personalBest! > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: HcSpace.s4),
            child: Text('Your best streak: $_personalBest', textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: HcSpace.s3),
            child: Text(_error!, textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
          ),
        FilledButton(style: HcButtons.large(), onPressed: _start, child: const Text('Start')),
      ],
    );
  }

  Widget _buildRunning(HcPalette hc) {
    final s = _session;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s3, HcSpace.s4, HcSpace.s3),
        child: Row(children: [
          HeroCard.tile(label: 'Streak', value: '$_idx'),
          const SizedBox(width: HcSpace.s2),
          HeroCard.tile(label: 'Next rating', value: s == null ? '—' : '${s.puzzle.rating}'),
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
              if (s.status == PuzzleStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: HcSpace.s2),
                  child: Text('Missed it. Streak over.', textAlign: TextAlign.center, style: HcText.titleSm.copyWith(color: hc.dangerInk)),
                ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildEnded(HcPalette hc) {
    final isBest = _personalBest != null && _finalStreak >= _personalBest!;
    return ListView(
      padding: const EdgeInsets.all(HcSpace.s4),
      children: [
        Icon(isBest && _finalStreak > 0 ? Icons.emoji_events_rounded : Icons.trending_up_rounded, size: 48, color: hc.gold),
        const SizedBox(height: HcSpace.s3),
        Text('Streak: $_finalStreak', style: HcText.displayXl.copyWith(color: hc.ink), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s1),
        if (isBest && _finalStreak > 0)
          Text('New personal best!', textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.green, fontWeight: FontWeight.w700))
        else if (_personalBest != null)
          Text('Personal best: $_personalBest', textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
        const SizedBox(height: HcSpace.s4),
        FilledButton(style: HcButtons.large(), onPressed: _start, child: const Text('Play again')),
        const SizedBox(height: HcSpace.s2),
        OutlinedButton(style: HcButtons.large(), onPressed: () => setState(() => _phase = _Phase.idle), child: const Text('Done')),
      ],
    );
  }
}
