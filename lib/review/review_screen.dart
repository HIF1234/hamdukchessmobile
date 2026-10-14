import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/telemetry.dart';
import '../engine/device.dart';
import '../engine/uci_engine.dart';
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

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final tier = reviewDepthFor(await Device.totalRamMb());
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
      if (mounted && r != null) setState(() => _result = r);
    } catch (e, st) {
      Telemetry.recordError(e, st, reason: 'game review');
      if (mounted) setState(() => _error = "The review couldn't run on this phone.");
    }
  }

  @override
  void dispose() {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Game review')),
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
        ChessBoardView(
          fen: m?.fenAfter ?? widget.startFen,
          whiteAtBottom: widget.whiteAtBottom,
          lastMove: m == null ? null : (m.uci.substring(0, 2), m.uci.substring(2, 4)),
          animate: !AppSettings.instance.lowData,
        ),
        const SizedBox(height: 8),
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
                if (m.classification.index >= Classification.inaccuracy.index && m.bestSan != null)
                  Text('Best was ${m.bestSan}'),
              ]),
            ),
          ),
        Row(children: [
          IconButton(onPressed: _selected < 0 ? null : () => setState(() => _selected--), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(
              'Accuracy: White ${r.accuracyWhite}% · Black ${r.accuracyBlack}%',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
              onPressed: _selected >= r.moves.length - 1 ? null : () => setState(() => _selected++),
              icon: const Icon(Icons.chevron_right)),
        ]),
        Text(
          'White: ${count(true, Classification.inaccuracy)} inaccuracies, ${count(true, Classification.mistake)} mistakes, '
          '${count(true, Classification.blunder)} blunders\n'
          'Black: ${count(false, Classification.inaccuracy)} inaccuracies, ${count(false, Classification.mistake)} mistakes, '
          '${count(false, Classification.blunder)} blunders',
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
              onSelected: (_) => setState(() => _selected = i),
            ),
        ]),
        const SizedBox(height: 8),
        Text('Stockfish 11 at depth ${r.depth}, on your phone.', style: t.textTheme.bodySmall),
      ],
    );
  }
}
