import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../analysis/ai_coach.dart';
import '../analysis/analysis_screen.dart';
import '../board/chess_board.dart';
import '../bots/bot_picker.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/keep_screen_on.dart';
import '../core/settings.dart';
import '../core/telemetry.dart';
import '../core/theme.dart';
import '../engine/device.dart';
import '../engine/uci_engine.dart';
import '../puzzles/puzzle_session.dart';
import 'game_review.dart';

/// Move-by-move review of a finished game, run by Stockfish on the phone. Depth follows the
/// phone's memory (lighter on 2 GB phones, spec §3).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.startFen, required this.sanMoves, required this.whiteAtBottom});
  final String startFen;
  final List<String> sanMoves;
  final bool whiteAtBottom;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  UciEngine? _engine;
  ReviewResult? _result;
  String? _error;
  bool _light = false;
  int _done = 0;
  int _selected = -1; // -1 = starting position
  bool _cancelled = false;
  List<(String, String)>? _bestArrows; // best-move arrows for the selected position
  bool _arrowsLoading = false;

  // "Explore lines": a free branch off the review, the player's own moves scored by the
  // engine, independent of the real game. Null means not exploring.
  ch.Chess? _exploreGame;
  List<(String san, int evalCp)> _exploreMoves = []; // evalCp from White's POV
  bool _exploreThinking = false;

  void _select(int i) => setState(() {
        _selected = i;
        _bestArrows = null;
      });

  String _positionFen(MoveReview? m) => _bestArrows != null && m != null ? m.fenBefore : (m?.fenAfter ?? widget.startFen);

  void _startExploring(MoveReview? m) => setState(() {
        _exploreGame = ch.Chess.fromFEN(_positionFen(m), check_validity: false);
        _exploreMoves = [];
        _bestArrows = null;
      });

  void _stopExploring() => setState(() {
        _exploreGame = null;
        _exploreMoves = [];
      });

  bool _onExploreMove(String from, String to, String? promo) {
    final g = _exploreGame;
    final engine = _engine;
    if (g == null || engine == null || _exploreThinking) return false;
    if (!g.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) return false;
    final san = g.getHistory().cast<String>().last;
    setState(() {
      _exploreMoves = [..._exploreMoves, (san, 0)];
      _exploreThinking = true;
    });
    _evaluateExploreMove(g, engine);
    return true;
  }

  Future<void> _evaluateExploreMove(ch.Chess g, UciEngine engine) async {
    try {
      if (g.in_checkmate) {
        _setLastExploreEval(g.turn == ch.Color.WHITE ? -100000 : 100000);
      } else if (g.in_stalemate || g.insufficient_material) {
        _setLastExploreEval(0);
      } else {
        final (_, lines) = await engine.analyse(g.fen, depth: 12, movetimeMs: 500, multiPv: 1);
        final stm = lines.isEmpty ? 0 : lines.first.score;
        _setLastExploreEval(g.turn == ch.Color.WHITE ? stm : -stm);
      }
    } finally {
      if (mounted) setState(() => _exploreThinking = false);
    }
  }

  void _setLastExploreEval(int whiteCp) {
    if (!mounted || _exploreMoves.isEmpty) return;
    setState(() => _exploreMoves[_exploreMoves.length - 1] = (_exploreMoves.last.$1, whiteCp));
  }

  @override
  void initState() {
    super.initState();
    KeepScreenOn.push();
    _run();
  }

  Future<void> _run() async {
    try {
      final tier = reviewDepthFor(
        await Device.totalRamMb(),
        engineDepth: AppSettings.instance.engineDepth,
        batterySaver: AppSettings.instance.engineBatterySaver,
      );
      setState(() => _light = tier.light);
      _engine = await UciEngine.start(await Device.stockfishPath());
      final r = await reviewGame(
        _engine!,
        startFen: widget.startFen,
        sanMoves: widget.sanMoves,
        depth: tier.depth,
        movetimeMs: tier.movetimeMs,
        onProgress: (d, _) {
          if (mounted) setState(() => _done = d);
        },
        isCancelled: () => _cancelled,
      );
      if (mounted && r != null) {
        setState(() => _result = r);
        _savePersonalPuzzles(r);
      }
    } catch (e, st) {
      Telemetry.recordError(e, st, reason: 'game review');
      if (mounted) setState(() => _error = "The review couldn't run on this phone.");
    }
  }

  /// "Puzzles from your games": saves this player's own blunders (not the opponent's) as
  /// personal training material under Puzzles ▸ From your games.
  Future<void> _savePersonalPuzzles(ReviewResult r) async {
    final blunders = [
      for (final m in r.moves)
        if (m.classification == Classification.blunder && m.white == widget.whiteAtBottom && m.bestMove != null)
          {'fen': m.fenBefore, 'bestMove': m.bestMove},
    ];
    if (blunders.isEmpty) return;
    try {
      final res = await Api.instance.post('/puzzles/from-games', {'blunders': blunders}) as Map;
      final added = (res['added'] as num?)?.toInt() ?? 0;
      if (added > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$added puzzle${added == 1 ? '' : 's'} from this game added to Puzzles.')),
        );
      }
    } on ApiError {
      // Best-effort; the review itself already shows regardless.
    }
  }

  /// The engine's best move and its next three alternatives for the position before the
  /// selected move, as arrows -- instead of only "Best was Nf3" as text.
  Future<void> _showBestMoves(MoveReview m) async {
    final engine = _engine;
    if (engine == null || _arrowsLoading) return;
    setState(() => _arrowsLoading = true);
    try {
      final (_, lines) = await engine.analyse(m.fenBefore, depth: 12, movetimeMs: 600, multiPv: 4);
      if (mounted) {
        setState(() => _bestArrows = [for (final l in lines) (l.move.substring(0, 2), l.move.substring(2, 4))]);
      }
    } finally {
      if (mounted) setState(() => _arrowsLoading = false);
    }
  }

  /// "Record or type what you were thinking on a move; the coach checks your reasoning
  /// against the engine." Typed only -- no voice recording built yet.
  Future<void> _thinkAloud(MoveReview m) async {
    final thoughtController = TextEditingController();
    String? markdown;
    String? error;
    var loading = false;
    var submitted = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> submit() async {
            final thought = thoughtController.text.trim();
            if (thought.length < 3) return;
            setSheetState(() {
              loading = true;
              submitted = true;
            });
            try {
              final r = await Api.instance.post('/coach/think-aloud', {
                'ply': m.ply,
                'fenBefore': m.fenBefore,
                'moveSan': m.san,
                'classification': m.classification.name,
                'cpLoss': m.cpLoss,
                'evalBefore': m.white ? m.evalBefore : -m.evalBefore,
                'evalAfter': m.white ? m.evalAfter : -m.evalAfter,
                'bestMoveSan': m.bestSan,
                'thought': thought,
                'language': AppSettings.instance.language == 'pcm' ? 'pcm' : 'en',
              }) as Map;
              markdown = r['markdown'] as String?;
              error = r['error'] as String?;
            } on ApiError catch (e) {
              error = e.message;
            } finally {
              setSheetState(() => loading = false);
            }
          }

          final hc = ctx.hc;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(HcSpace.s4),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('What were you thinking on ${m.san}?', style: HcText.titleMd.copyWith(color: hc.ink)),
                  const SizedBox(height: HcSpace.s3),
                  if (!submitted) ...[
                    TextField(
                      controller: thoughtController,
                      maxLines: 4,
                      autofocus: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'I thought this move won a pawn...'),
                    ),
                    const SizedBox(height: HcSpace.s3),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(style: HcButtons.large(), onPressed: submit, child: const Text('Ask the coach')),
                    ),
                  ] else if (loading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else if (error != null)
                    Text(error!, style: HcText.bodySm.copyWith(color: hc.dangerInk))
                  else
                    Text(markdown ?? '', style: HcText.body.copyWith(color: hc.ink)),
                  const SizedBox(height: HcSpace.s3),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    KeepScreenOn.pop();
    _cancelled = true;
    _engine?.dispose();
    super.dispose();
  }

  String _eval(int cp) {
    if (cp.abs() >= 90000) return cp > 0 ? 'White mates' : 'Black mates';
    final p = cp / 100;
    return '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = _result;
    final total = widget.sanMoves.length;
    final currentFen = r == null ? widget.startFen : _positionFen(_selected >= 0 ? r.moves[_selected] : null);
    return Scaffold(
      appBar: AppBar(title: const Text('Game review'), actions: [
        IconButton(
          tooltip: 'Open in Analysis board',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnalysisScreen(startFen: currentFen))),
          icon: const Icon(Icons.explore_outlined),
        ),
      ]),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : r == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Reviewing move $_done of $total…'),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: total == 0 ? null : _done / total),
                      if (_light) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Your phone has less memory, so this is a lighter review to keep it running '
                          'smoothly. It still catches blunders and mistakes; small inaccuracies may be missed.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ]),
                  )
                : _results(r, t),
      ),
    );
  }

  Widget _results(ReviewResult r, ThemeData t) {
    final m = _selected >= 0 ? r.moves[_selected] : null;
    int count(bool white, Classification c) => r.moves.where((x) => x.white == white && x.classification == c).length;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_exploreGame == null) _EvalGraph(moves: r.moves, selected: _selected, onSelect: _select),
        const SizedBox(height: 8),
        ChessBoardView(
          fen: _exploreGame?.fen ?? _positionFen(m),
          whiteAtBottom: widget.whiteAtBottom,
          onMove: _exploreGame != null && !_exploreThinking ? _onExploreMove : null,
          lastMove: _exploreGame != null || _bestArrows != null
              ? null
              : (m == null ? null : (m.uci.substring(0, 2), m.uci.substring(2, 4))),
          lastMoveSan: _exploreGame != null || _bestArrows != null ? null : m?.san,
          arrows: _bestArrows ?? const [],
          animate: !AppSettings.instance.lowData,
        ),
        const SizedBox(height: 8),
        if (_exploreGame != null) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (san, cp) in _exploreMoves) Chip(label: Text('$san  ${_eval(cp)}')),
            if (_exploreThinking) const Chip(label: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ]),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: _stopExploring, child: const Text('Return to the game')),
          const SizedBox(height: 8),
        ],
        if (_exploreGame == null) ...[
          if (m != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ReviewBadge(kind: m.classification.name),
                    const SizedBox(width: 8),
                    Text('${(m.ply + 1) ~/ 2}${m.white ? '.' : '...'} ${m.san}  ${m.classification.label}',
                        style: t.textTheme.titleMedium),
                  ]),
                  Text('Evaluation ${_eval(m.evalAfter)}'),
                  if (m.classification.index >= Classification.inaccuracy.index && m.bestSan != null) ...[
                    Text('Best was ${m.bestSan}'),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: _arrowsLoading ? null : () => _showBestMoves(m),
                      icon: _arrowsLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.north_east_rounded, size: 16),
                      label: Text(_bestArrows != null ? 'Showing best moves' : 'Show best moves'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () => askAiCoach(context, m.fenBefore),
                      icon: const Icon(Icons.psychology_outlined, size: 16),
                      label: const Text('Ask the coach'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _thinkAloud(m),
                      icon: const Icon(Icons.mic_none_rounded, size: 16),
                      label: const Text('Think aloud'),
                    ),
                  ]),
                ]),
              ),
            ),
          Row(children: [
            IconButton(onPressed: _selected < 0 ? null : () => _select(_selected - 1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                'Accuracy: White ${r.accuracyWhite}% · Black ${r.accuracyBlack}%',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
                onPressed: _selected >= r.moves.length - 1 ? null : () => _select(_selected + 1),
                icon: const Icon(Icons.chevron_right)),
          ]),
          Text(
            'White: ${count(true, Classification.brilliant)} brilliant, ${count(true, Classification.great)} great, '
            '${count(true, Classification.inaccuracy)} inaccuracies, ${count(true, Classification.mistake)} mistakes, '
            '${count(true, Classification.miss)} misses, ${count(true, Classification.blunder)} blunders\n'
            'Black: ${count(false, Classification.brilliant)} brilliant, ${count(false, Classification.great)} great, '
            '${count(false, Classification.inaccuracy)} inaccuracies, ${count(false, Classification.mistake)} mistakes, '
            '${count(false, Classification.miss)} misses, ${count(false, Classification.blunder)} blunders',
            style: t.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final (i, mv) in r.moves.indexed)
              ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  ReviewBadge(kind: mv.classification.name, size: 14),
                  const SizedBox(width: 4),
                  Text('${mv.white ? '${(mv.ply + 1) ~/ 2}.' : ''}${mv.san}'),
                ]),
                selected: _selected == i,
                onSelected: (_) => _select(i),
              ),
          ]),
          if (keyMoments(r.moves).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Key moments', style: t.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final km in keyMoments(r.moves))
              InkWell(
                onTap: () => _select(km.ply - 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• ${keyMomentSentence(km)}', style: t.textTheme.bodySmall),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _startExploring(m),
              icon: const Icon(Icons.alt_route_rounded),
              label: const Text('Explore from here'),
            ),
            if (_mistakesToRetry(r).isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _RetryMistakesScreen(mistakes: _mistakesToRetry(r)),
                )),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Retry your mistakes'),
              ),
            OutlinedButton.icon(
              onPressed: () => playBotFromPosition(context, fen: m?.fenAfter ?? widget.startFen, playWhite: widget.whiteAtBottom),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Play from here vs a bot'),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Stockfish 11 at depth ${r.depth}, on your phone.', style: t.textTheme.bodySmall),
        ],
      ],
    );
  }

  /// The player's own mistakes/misses/blunders -- "find the better move yourself" only
  /// makes sense for moves they played.
  List<MoveReview> _mistakesToRetry(ReviewResult r) => r.moves
      .where((m) =>
          m.white == widget.whiteAtBottom &&
          m.bestMove != null &&
          (m.classification == Classification.mistake ||
              m.classification == Classification.miss ||
              m.classification == Classification.blunder))
      .toList();
}

/// The whole game's evaluation as a graph across the top; tap (or drag) any point to jump
/// there. Points: index 0 is the starting position, index i+1 is moves[i].evalAfter --
/// [selected] follows review_screen's own -1-for-start convention, [onSelect] expects that
/// same convention back.
class _EvalGraph extends StatelessWidget {
  const _EvalGraph({required this.moves, required this.selected, required this.onSelect});
  final List<MoveReview> moves;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _cap = 600;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final points = <int>[0, for (final m in moves) m.evalAfter];
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          void handleTap(Offset local) {
            if (points.length < 2) return;
            final i = (local.dx / size.width * (points.length - 1)).round().clamp(0, points.length - 1);
            onSelect(i - 1);
          }

          return GestureDetector(
            onTapDown: (d) => handleTap(d.localPosition),
            onHorizontalDragUpdate: (d) => handleTap(d.localPosition),
            child: CustomPaint(
              size: size,
              painter: _EvalGraphPainter(
                points: points,
                selected: selected + 1,
                white: hc.green,
                black: hc.ink,
                mid: hc.line,
                marker: hc.ink2,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EvalGraphPainter extends CustomPainter {
  _EvalGraphPainter({
    required this.points,
    required this.selected,
    required this.white,
    required this.black,
    required this.mid,
    required this.marker,
  });
  final List<int> points;
  final int selected;
  final Color white;
  final Color black;
  final Color mid;
  final Color marker;

  double _y(int cp, double h) {
    final clamped = cp.clamp(-_EvalGraph._cap, _EvalGraph._cap);
    return h / 2 - (clamped / _EvalGraph._cap) * (h / 2 - 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final n = points.length;
    final dx = size.width / (n - 1);
    final midY = size.height / 2;

    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), Paint()
      ..color = mid.withValues(alpha: 0.4)
      ..strokeWidth = 1);

    for (var i = 0; i < n - 1; i++) {
      final x1 = i * dx, x2 = (i + 1) * dx;
      final y1 = _y(points[i], size.height), y2 = _y(points[i + 1], size.height);
      final favorsWhite = points[i] + points[i + 1] >= 0;
      final color = favorsWhite ? white : black;
      final fill = Path()
        ..moveTo(x1, midY)
        ..lineTo(x1, y1)
        ..lineTo(x2, y2)
        ..lineTo(x2, midY)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), Paint()
        ..color = color
        ..strokeWidth = 1.5);
    }
    if (selected >= 0 && selected < n) {
      final x = selected * dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
        ..color = marker
        ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _EvalGraphPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.selected != selected;
}

/// "Retry your mistakes": steps through the moves this player got wrong, each as a one-move
/// puzzle (find the engine's best move before it's shown), reusing the same session class
/// the Puzzles tab uses.
class _RetryMistakesScreen extends StatefulWidget {
  const _RetryMistakesScreen({required this.mistakes});
  final List<MoveReview> mistakes;

  @override
  State<_RetryMistakesScreen> createState() => _RetryMistakesScreenState();
}

class _RetryMistakesScreenState extends State<_RetryMistakesScreen> {
  int _idx = 0;
  late PuzzleSession _session = _sessionFor(0);

  PuzzleSession _sessionFor(int i) {
    final m = widget.mistakes[i];
    return PuzzleSession(Puzzle(id: 'retry-${m.ply}', fen: m.fenBefore, solution: [m.bestMove!], themes: const [], rating: 0));
  }

  bool _onMove(String from, String to, String? promo) {
    final ok = _session.tryMove(from, to, promo);
    if (ok) setState(() {});
    return ok;
  }

  void _next() {
    if (_idx >= widget.mistakes.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _idx++;
      _session = _sessionFor(_idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final s = _session;
    final m = widget.mistakes[_idx];
    return Scaffold(
      appBar: AppBar(title: Text('Retry your mistakes (${_idx + 1}/${widget.mistakes.length})')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(HcSpace.s4),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HcRadius.board),
              child: ChessBoardView(
                key: ValueKey('${m.ply}-$_idx'),
                fen: s.fen,
                whiteAtBottom: m.white,
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
                PuzzleStatus.playing => '${m.white ? 'White' : 'Black'} to play -- find the move you missed.',
                PuzzleStatus.solved => 'Correct!',
                PuzzleStatus.failed => 'Not quite. The best move was ${m.bestSan ?? s.puzzle.solution.first}.',
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
                  onPressed: _next,
                  child: Text(_idx >= widget.mistakes.length - 1 ? 'Done' : 'Next'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
