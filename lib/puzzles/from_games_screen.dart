import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'puzzle_session.dart';

/// "Your own mistakes turned into puzzles after each review." Saved by review_screen.dart
/// right after an on-device review finds a blunder; this just lists and retries them. No
/// design spec or web equivalent exists for this; built with the app's own tokens.
class FromGamesScreen extends StatefulWidget {
  const FromGamesScreen({super.key});

  @override
  State<FromGamesScreen> createState() => _FromGamesScreenState();
}

class _FromGamesScreenState extends State<FromGamesScreen> {
  List<Map<String, dynamic>>? _puzzles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/puzzles/from-games') as Map;
      if (mounted) setState(() => _puzzles = (r['puzzles'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// "From a game today" / "...yesterday" / "...3 days ago" / "...on 12 Oct".
  String _fromLabel(String iso) {
    final created = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(created.year, created.month, created.day)).inDays;
    if (days <= 0) return 'From a game today';
    if (days == 1) return 'From a game yesterday';
    if (days < 14) return 'From a game $days days ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'From a game on ${created.day} ${months[created.month - 1]}';
  }

  Puzzle _toPuzzle(Map<String, dynamic> p) => Puzzle(
        id: p['id'] as String,
        fen: p['fen'] as String,
        solution: [p['best_move'] as String],
        themes: const [],
        rating: 0,
      );

  Future<void> _retry(Map<String, dynamic> p) async {
    final solved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _FromGamesRetryScreen(puzzle: _toPuzzle(p))),
    );
    if (solved == true && mounted) setState(() => _puzzles?.removeWhere((x) => x['id'] == p['id']));
  }

  @override
  Widget build(BuildContext context) {
    final puzzles = _puzzles;
    return Scaffold(
      appBar: AppBar(title: const Text('From your games')),
      body: puzzles == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : puzzles.isEmpty
              ? const EmptyState(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Nothing here yet',
                  body: 'Review a finished game -- your own blunders turn into puzzles here.',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: HcSpace.s4),
                  children: [
                    for (final p in puzzles)
                      HcListRow(
                        title: 'Blunder to fix',
                        subtitle: _fromLabel(p['created_at'] as String),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _retry(p),
                      ),
                  ],
                ),
    );
  }
}

/// Retries one "from your games" puzzle; pops `true` if this attempt solves it.
class _FromGamesRetryScreen extends StatefulWidget {
  const _FromGamesRetryScreen({required this.puzzle});
  final Puzzle puzzle;

  @override
  State<_FromGamesRetryScreen> createState() => _FromGamesRetryScreenState();
}

class _FromGamesRetryScreenState extends State<_FromGamesRetryScreen> {
  late final PuzzleSession _session = PuzzleSession(widget.puzzle);
  bool _submitting = false;

  bool _onMove(String from, String to, String? promo) {
    final s = _session;
    final ok = s.tryMove(from, to, promo);
    if (!ok) return false;
    setState(() {});
    _finishIfDone(s); // single-ply solution: never awaits a reply
    return true;
  }

  Future<void> _finishIfDone(PuzzleSession s) async {
    if (s.status == PuzzleStatus.playing || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Api.instance.post('/puzzles/from-games/${s.puzzle.id}/attempt', {
        'success': s.status == PuzzleStatus.solved,
      });
    } on ApiError {
      // The solve itself still shows even if marking it solved server-side didn't land.
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
                onMove: s.status == PuzzleStatus.playing ? _onMove : null,
                animate: !AppSettings.instance.lowData,
              ),
            ),
            const SizedBox(height: HcSpace.s3),
            Text(
              switch (s.status) {
                PuzzleStatus.playing => '${s.whiteToSolve ? 'White' : 'Black'} to play -- find the move you missed.',
                PuzzleStatus.solved => 'Solved!',
                PuzzleStatus.failed => 'Not quite. The best move was ${s.puzzle.solution.first}.',
              },
              style: HcText.titleMd.copyWith(color: hc.ink),
            ),
            const SizedBox(height: HcSpace.s3),
            if (s.status != PuzzleStatus.playing)
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
