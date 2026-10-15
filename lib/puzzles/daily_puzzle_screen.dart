import 'package:flutter/material.dart';

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
      Telemetry.puzzleFinished(solved: s.status == PuzzleStatus.solved, offline: false);
    } on ApiError {
      // The streak/rating update just didn't go through; the solve itself still shows.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                              : 'Solved!',
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
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
