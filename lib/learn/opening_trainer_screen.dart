import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../analysis/analysis_screen.dart' show standardStartFen;

/// Plays through one opening line move-by-move: the board auto-plays the book move for the
/// opponent, and the player must find their own side's book move. Wrong moves count as
/// attempts but don't stop the session -- after 3 in a row on the same move, the "from"
/// square is highlighted as a hint. Mirrors the website's OpeningTrainer mechanic exactly
/// (no separate spaced-repetition scheduler exists there either -- "repeated until
/// remembered" just means retrying the same move until it's right).
class OpeningTrainerScreen extends StatefulWidget {
  const OpeningTrainerScreen({super.key, required this.opening});
  final Map<String, dynamic> opening;

  @override
  State<OpeningTrainerScreen> createState() => _OpeningTrainerScreenState();
}

class _OpeningTrainerScreenState extends State<OpeningTrainerScreen> {
  late final List<String> _moves = (widget.opening['moves'] as List).cast<String>();
  late final bool _userIsWhite = widget.opening['color'] == 'white';

  int _ply = 0;
  String _fen = standardStartFen;
  int _wrongCount = 0;
  bool _hintOn = false;
  int _correct = 0;
  int _attempts = 0;
  bool _done = false;
  bool _reported = false;
  Timer? _autoPlayTimer;

  bool get _isUserTurn => (_ply.isEven) == _userIsWhite;

  @override
  void initState() {
    super.initState();
    _maybeAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _maybeAutoPlay() {
    if (_done || _ply >= _moves.length) {
      _finish();
      return;
    }
    if (_isUserTurn) return;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      final move = _moves[_ply];
      final g = ch.Chess.fromFEN(_fen, check_validity: false);
      final ok = g.move({'from': move.substring(0, 2), 'to': move.substring(2, 4), 'promotion': move.length > 4 ? move[4] : 'q'});
      if (ok == false) return;
      setState(() {
        _fen = g.fen;
        _ply++;
        _wrongCount = 0;
        _hintOn = false;
      });
      _maybeAutoPlay();
    });
  }

  bool _attemptMove(String from, String to, String? promotion) {
    if (!_isUserTurn || _done) return false;
    final answer = _moves[_ply];
    final aFrom = answer.substring(0, 2);
    final aTo = answer.substring(2, 4);
    final aPromo = answer.length > 4 ? answer[4] : null;
    final match = from == aFrom && to == aTo && (aPromo == null || promotion == aPromo);
    setState(() => _attempts++);
    if (!match) {
      setState(() => _wrongCount++);
      return false;
    }
    final g = ch.Chess.fromFEN(_fen, check_validity: false);
    g.move({'from': from, 'to': to, 'promotion': promotion ?? aPromo ?? 'q'});
    setState(() {
      _fen = g.fen;
      _correct++;
      _wrongCount = 0;
      _hintOn = false;
      _ply++;
    });
    _maybeAutoPlay();
    return true;
  }

  Future<void> _finish() async {
    if (_done) return;
    setState(() => _done = true);
    if (_reported) return;
    _reported = true;
    try {
      await Api.instance.post('/openings/progress', {
        'eco': widget.opening['eco'],
        'correct': _correct,
        'attempts': _attempts,
        'masteredDepth': _ply,
      });
    } on ApiError {
      // Best-effort; the session itself already played out fine.
    }
  }

  void _restart() {
    _autoPlayTimer?.cancel();
    setState(() {
      _ply = 0;
      _fen = standardStartFen;
      _wrongCount = 0;
      _hintOn = false;
      _correct = 0;
      _attempts = 0;
      _done = false;
      _reported = false;
    });
    _maybeAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final opening = widget.opening;
    final ideas = (opening['ideas'] as List?)?.cast<String>() ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(opening['name'] as String)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HcSpace.s4),
          children: [
            Text(opening['description'] as String? ?? '', style: HcText.body.copyWith(color: hc.ink2)),
            const SizedBox(height: HcSpace.s3),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(HcRadius.board),
                child: ChessBoardView(
                  fen: _fen,
                  whiteAtBottom: _userIsWhite,
                  hintSquare: _hintOn && _isUserTurn && !_done ? _moves[_ply].substring(0, 2) : null,
                  onMove: _isUserTurn && !_done ? _attemptMove : null,
                  animate: !AppSettings.instance.lowData,
                ),
              ),
            ),
            const SizedBox(height: HcSpace.s3),
            if (_done)
              Column(children: [
                Text('$_correct / $_attempts correct this session', style: HcText.titleMd.copyWith(color: hc.ink)),
                const SizedBox(height: HcSpace.s3),
                FilledButton(onPressed: _restart, style: HcButtons.large(), child: const Text('Play again')),
              ])
            else
              Text(
                _isUserTurn ? "Your move -- play ${opening['color']}'s book line." : "Opponent's book move...",
                style: HcText.titleMd.copyWith(color: hc.ink),
                textAlign: TextAlign.center,
              ),
            if (_wrongCount >= 3 && !_hintOn && !_done)
              Padding(
                padding: const EdgeInsets.only(top: HcSpace.s2),
                child: Center(
                  child: TextButton(onPressed: () => setState(() => _hintOn = true), child: const Text('Show a hint')),
                ),
              ),
            if (ideas.isNotEmpty) ...[
              const SizedBox(height: HcSpace.s4),
              Text('Ideas', style: HcText.label.copyWith(color: hc.green)),
              const SizedBox(height: 6),
              for (final idea in ideas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $idea', style: HcText.bodySm.copyWith(color: hc.ink2)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
