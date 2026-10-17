import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'puzzle_session.dart';
import 'puzzles_screen.dart' show puzzleThemes;

/// "Failed puzzles to retry, with the date you missed each one." No design spec or web
/// equivalent exists for this; built with the app's own tokens like theme_stats_screen.
class MissesScreen extends StatefulWidget {
  const MissesScreen({super.key});

  @override
  State<MissesScreen> createState() => _MissesScreenState();
}

class _MissesScreenState extends State<MissesScreen> {
  List<Map<String, dynamic>>? _misses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/puzzles/misses') as Map;
      if (mounted) setState(() => _misses = (r['misses'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _label(String key) => puzzleThemes.firstWhere((t) => t.$1 == key, orElse: () => (key, key)).$2;

  /// "Missed today" / "Missed yesterday" / "Missed 3 days ago" / "Missed on 12 Oct".
  String _missedLabel(String iso) {
    final missed = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(missed.year, missed.month, missed.day)).inDays;
    if (days <= 0) return 'Missed today';
    if (days == 1) return 'Missed yesterday';
    if (days < 14) return 'Missed $days days ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Missed on ${missed.day} ${months[missed.month - 1]}';
  }

  Future<void> _retry(Map<String, dynamic> miss) async {
    final solved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _MissRetryScreen(puzzle: Puzzle.fromJson(miss))),
    );
    if (solved == true && mounted) setState(() => _misses?.removeWhere((m) => m['id'] == miss['id']));
  }

  @override
  Widget build(BuildContext context) {
    final misses = _misses;
    return Scaffold(
      appBar: AppBar(title: const Text('Your misses')),
      body: misses == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : misses.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No misses right now',
                  body: 'Puzzles you get wrong show up here so you can retry them.',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: HcSpace.s4),
                  children: [
                    for (final m in misses)
                      HcListRow(
                        title: (m['themes'] as List).isNotEmpty
                            ? _label((m['themes'] as List).first as String)
                            : 'Puzzle',
                        subtitle: '${_missedLabel(m['missedAt'] as String)} · rated ${m['rating']}',
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _retry(m),
                      ),
                  ],
                ),
    );
  }
}

/// Retries one missed puzzle; pops `true` if this attempt solves it.
class _MissRetryScreen extends StatefulWidget {
  const _MissRetryScreen({required this.puzzle});
  final Puzzle puzzle;

  @override
  State<_MissRetryScreen> createState() => _MissRetryScreenState();
}

class _MissRetryScreenState extends State<_MissRetryScreen> {
  late final PuzzleSession _session = PuzzleSession(widget.puzzle);
  bool _submitting = false;

  bool _onMove(String from, String to, String? promo) {
    final s = _session;
    final ok = s.tryMove(from, to, promo);
    if (!ok) return false;
    setState(() {});
    if (s.awaitingReply) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(s.playReply);
        _finishIfDone(s);
      });
    } else {
      _finishIfDone(s);
    }
    return true;
  }

  Future<void> _finishIfDone(PuzzleSession s) async {
    if (s.status == PuzzleStatus.playing || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Api.instance.post('/puzzles/${s.puzzle.id}/attempt', {
        'success': s.status == PuzzleStatus.solved,
        'hintsUsed': s.maxHintLevel,
      });
    } on ApiError {
      // The rating update just didn't go through; the solve itself still shows.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final s = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Retry')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(HcSpace.s4),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HcRadius.board),
              child: ChessBoardView(
                key: ValueKey(s.puzzle.id),
                fen: s.fen,
                whiteAtBottom: s.whiteToSolve,
                lastMove: s.lastMove,
                lastMoveSan: s.lastSan,
                hintSquare: s.hintFrom,
                arrow: s.hintTo != null ? (s.hintFrom!, s.hintTo!) : null,
                onMove: s.status == PuzzleStatus.playing && !s.awaitingReply ? _onMove : null,
                animate: !AppSettings.instance.lowData,
              ),
            ),
            const SizedBox(height: HcSpace.s3),
            Text(
              switch (s.status) {
                PuzzleStatus.playing => '${s.whiteToSolve ? 'White' : 'Black'} to play · rated ${s.puzzle.rating}',
                PuzzleStatus.solved => 'Solved!',
                PuzzleStatus.failed => 'Not quite. The best move was ${s.puzzle.solution.first}.',
              },
              style: HcText.titleMd.copyWith(color: hc.ink),
            ),
            const SizedBox(height: HcSpace.s3),
            if (s.status == PuzzleStatus.playing)
              TextButton(
                onPressed: s.hintLevel >= 2 ? null : () => setState(s.showHint),
                child: Text(s.hintLevel == 0 ? 'Hint' : 'Show move'),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: HcButtons.large(),
                  onPressed: () => Navigator.of(context).pop(s.status == PuzzleStatus.solved),
                  child: const Text('Done'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
