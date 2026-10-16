import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/telemetry.dart';
import '../core/theme.dart';
import 'puzzle_session.dart';

/// Today's puzzle, solved in one tap from Play's daily puzzle card -- separate from the
/// themed-pack flow in PuzzlesScreen (no offline pack, no theme picker: just today's one
/// puzzle, submitted straight to /puzzles/{id}/attempt since it needs a connection anyway
/// to have been fetched at all).
class DailyPuzzleScreen extends StatefulWidget {
  const DailyPuzzleScreen({super.key});

  @override
  State<DailyPuzzleScreen> createState() => _DailyPuzzleScreenState();
}

class _DailyPuzzleScreenState extends State<DailyPuzzleScreen> {
  PuzzleSession? _session;
  String? _error;
  bool _submitting = false;
  int? _streak;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final j = await Api.instance.get('/puzzles/daily');
      if (j == null) {
        if (mounted) setState(() => _error = 'No daily puzzle today. Try again tomorrow.');
        return;
      }
      final puzzle = Puzzle.fromJson(j as Map<String, dynamic>);
      if (mounted) setState(() => _session = PuzzleSession(puzzle));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool _onMove(String from, String to, String? promo) {
    final s = _session;
    if (s == null) return false;
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
      // Best-effort: analytics failing shouldn't skip the streak reload below.
      try {
        Telemetry.puzzleFinished(solved: s.status == PuzzleStatus.solved, offline: false);
      } catch (_) {}
      if (s.status == PuzzleStatus.solved) await _loadStreak();
    } on ApiError {
      // The streak/rating update just didn't go through; the solve itself still shows.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The "solve at least one puzzle a day" streak -- the same counter PuzzlesScreen shows,
  /// since it's kept across both the daily puzzle and themed-pack solving, not daily-only.
  Future<void> _loadStreak() async {
    try {
      final me = await Api.instance.get('/me') as Map;
      final streak = ((me['puzzles'] as Map?)?['current_streak'] as num?)?.toInt();
      if (mounted) setState(() => _streak = streak);
    } catch (_) {
      // Best-effort; the solve itself already shows regardless.
    }
  }

  void _share(PuzzleSession s) {
    final streak = _streak;
    final how = s.maxHintLevel >= 2 ? 'with the move shown' : (s.maxHintLevel == 1 ? 'with a hint' : 'first try');
    SharePlus.instance.share(ShareParams(
      text: "I solved today's Hamduk Chess puzzle, $how!"
          '${streak != null && streak > 0 ? ' $streak-day streak.' : ''}'
          ' play.chess.hamduk.com.ng/puzzles/daily',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final s = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily puzzle')),
      body: SafeArea(
        top: false,
        child: s == null
            ? Center(
                child: _error != null
                    ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                    : const CircularProgressIndicator(),
              )
            : ListView(
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
                      PuzzleStatus.solved => s.maxHintLevel >= 2
                          ? 'Solved! No rating gained (move was shown).'
                          : s.maxHintLevel == 1
                              ? 'Solved! Reduced rating gain (hint used).'
                              : 'Solved first try!',
                      PuzzleStatus.failed => 'Not quite. The best move was ${s.puzzle.solution.first}.',
                    },
                    style: HcText.titleMd.copyWith(color: hc.ink),
                  ),
                  if (s.status == PuzzleStatus.solved && (_streak ?? 0) > 0) ...[
                    const SizedBox(height: HcSpace.s1),
                    Text(
                      '$_streak-day streak',
                      style: HcText.bodySm.copyWith(color: hc.ink2),
                    ),
                  ],
                  const SizedBox(height: HcSpace.s3),
                  if (s.status == PuzzleStatus.playing)
                    TextButton(
                      onPressed: s.hintLevel >= 2 ? null : () => setState(s.showHint),
                      child: Text(s.hintLevel == 0 ? 'Hint' : 'Show move'),
                    )
                  else ...[
                    if (s.status == PuzzleStatus.solved)
                      Padding(
                        padding: const EdgeInsets.only(bottom: HcSpace.s2),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _share(s),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Share'),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: HcButtons.large(),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
