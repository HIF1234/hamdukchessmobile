import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/fen.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';

const _roundSeconds = 10;

enum _RoundType { hanging, check }

class _Round {
  _Round(this.fen, this.type, this.targets);
  final String fen;
  final _RoundType type;
  final Set<String> targets;
}

/// "Spot the hanging piece or the checking move within 10 seconds." A batch of positions
/// from GET /board-vision/puzzles, classified client-side: a puzzle themed hangingPiece
/// gives its own solution's capture square as the hanging piece; any other position is
/// scanned by plain chess rules (package:chess's verbose move list already appends '+'/'#'
/// to a move's SAN) for a legal move that gives check -- no puzzle theme covers that, since
/// it isn't a tactic, just a rule.
class BoardVisionScreen extends StatefulWidget {
  const BoardVisionScreen({super.key});

  @override
  State<BoardVisionScreen> createState() => _BoardVisionScreenState();
}

class _BoardVisionScreenState extends State<BoardVisionScreen> {
  List<_Round>? _rounds;
  String? _error;
  int _index = 0;
  Timer? _timer;
  int _secondsLeft = _roundSeconds;
  String? _feedbackSquare;
  bool? _lastCorrect;
  int _correct = 0;
  int _total = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Set<String> _checkTargets(String fen) {
    try {
      final g = ch.Chess.fromFEN(fen, check_validity: false);
      final moves = g.moves({'verbose': true}).cast<Map>();
      return moves.where((m) => (m['san'] as String).contains('+')).map((m) => m['to'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/board-vision/puzzles') as Map;
      final raw = (r['puzzles'] as List).cast<Map>();
      final rounds = <_Round>[];
      for (final p in raw) {
        final fen = p['fen'] as String;
        final themes = (p['themes'] as List?)?.cast<String>() ?? const [];
        final solution = (p['solution'] as List?)?.cast<String>() ?? const [];
        if (themes.contains('hangingPiece') && solution.isNotEmpty) {
          rounds.add(_Round(fen, _RoundType.hanging, {solution.first.substring(2, 4)}));
          continue;
        }
        final targets = _checkTargets(fen);
        if (targets.isNotEmpty) rounds.add(_Round(fen, _RoundType.check, targets));
      }
      if (!mounted) return;
      if (rounds.isEmpty) {
        setState(() => _error = 'No drills available right now.');
        return;
      }
      setState(() => _rounds = rounds);
      _startRound();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _startRound() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _roundSeconds;
      _feedbackSquare = null;
      _lastCorrect = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timeout();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _timeout() {
    _timer?.cancel();
    setState(() {
      _total++;
      _lastCorrect = false;
    });
    Timer(const Duration(milliseconds: 600), _next);
  }

  void _tap(String square) {
    if (_lastCorrect != null) return;
    _timer?.cancel();
    final correct = _rounds![_index].targets.contains(square);
    setState(() {
      _total++;
      if (correct) _correct++;
      _feedbackSquare = square;
      _lastCorrect = correct;
    });
    Timer(const Duration(milliseconds: 500), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _rounds!.length) {
      setState(() => _done = true);
      return;
    }
    setState(() => _index++);
    _startRound();
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correct = 0;
      _total = 0;
      _done = false;
    });
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final rounds = _rounds;
    return Scaffold(
      appBar: AppBar(title: const Text('Board vision')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HcSpace.s4),
          child: _error != null
              ? Center(child: Text(_error!, style: HcText.body.copyWith(color: hc.ink2), textAlign: TextAlign.center))
              : rounds == null
                  ? const Center(child: CircularProgressIndicator())
                  : _done
                      ? _resultsView(hc)
                      : _roundView(hc, rounds[_index]),
        ),
      ),
    );
  }

  Widget _resultsView(HcPalette hc) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_correct / $_total correct', style: HcText.displayMd.copyWith(color: hc.ink)),
          const SizedBox(height: HcSpace.s4),
          FilledButton(onPressed: _restart, style: HcButtons.large(), child: const Text('Play again')),
        ]),
      );

  Widget _roundView(HcPalette hc, _Round round) {
    final placement = placementFromFen(round.fen);
    return ListView(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_index + 1} / ${_rounds!.length}', style: HcText.titleMd.copyWith(color: hc.ink)),
          Text('${_secondsLeft}s', style: HcText.clockSm.copyWith(color: hc.ink)),
        ]),
        const SizedBox(height: HcSpace.s3),
        Text(
          round.type == _RoundType.hanging ? 'Tap the hanging piece.' : 'Tap a square a piece could move to for check.',
          style: HcText.titleMd.copyWith(color: hc.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HcSpace.s3),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
            itemCount: 64,
            itemBuilder: (context, i) {
              final file = 'abcdefgh'[i % 8];
              final rank = 8 - i ~/ 8;
              final square = '$file$rank';
              final light = (i % 8 + i ~/ 8) % 2 == 0;
              final piece = placement[square];
              Color? overlay;
              if (_feedbackSquare == square) overlay = _lastCorrect == true ? hc.greenSoft : hc.dangerSoft;
              return GestureDetector(
                key: Key('square_$square'),
                onTap: _lastCorrect == null ? () => _tap(square) : null,
                child: Container(
                  color: overlay ?? (light ? hc.surface2 : hc.surface3),
                  alignment: Alignment.center,
                  child: Text(piece != null ? pieceGlyph[piece] ?? '' : '', style: const TextStyle(fontSize: 26)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
