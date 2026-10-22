import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/keep_screen_on.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../engine/device.dart';
import '../engine/uci_engine.dart';
import '../review/game_review.dart' show reviewDepthFor;

/// "Win or hold the position against the engine." Plays one endgame drill position: the
/// player's move is checked for mate/promotion/the move budget, then Stockfish replies on
/// its own, same as the website's EndgameTrainer (checkmate ends it, draw/stalemate ends it,
/// a promotion wins a "promote" goal, running out of moves loses unless the goal is "draw").
class EndgameTrainerScreen extends StatefulWidget {
  const EndgameTrainerScreen({super.key, required this.endgame});
  final Map<String, dynamic> endgame;

  @override
  State<EndgameTrainerScreen> createState() => _EndgameTrainerScreenState();
}

class _EndgameTrainerScreenState extends State<EndgameTrainerScreen> {
  UciEngine? _engine;
  String? _engineError;
  late String _fen = widget.endgame['fen'] as String;
  int _moveCount = 0;
  String _outcome = 'playing'; // playing | won | lost | drawn
  bool _thinking = false;
  String? _hintSquare;
  bool _reported = false;

  String get _userColor => (widget.endgame['userColor'] as String) == 'white' ? 'w' : 'b';
  bool get _isUserTurn => _fen.split(' ')[1] == _userColor;
  Map<String, dynamic> get _goal => widget.endgame['goal'] as Map<String, dynamic>;

  @override
  void initState() {
    super.initState();
    KeepScreenOn.push();
    _startEngine();
  }

  @override
  void dispose() {
    KeepScreenOn.pop();
    _engine?.dispose();
    super.dispose();
  }

  Future<void> _startEngine() async {
    try {
      _engine = await UciEngine.start(await Device.stockfishPath());
      if (!_isUserTurn) _engineTurn();
    } catch (e) {
      if (mounted) setState(() => _engineError = "The engine couldn't start on this phone.");
    }
  }

  void _evaluate(ch.Chess g, int moves, {bool userPromoted = false}) {
    if (_reported) return;
    final goalKind = _goal['kind'] as String;
    final maxMoves = (_goal['maxMoves'] as num).toInt();
    if (g.in_checkmate) {
      final matedColor = g.fen.split(' ')[1];
      final winner = matedColor == 'w' ? 'b' : 'w';
      if (goalKind == 'mate' && winner == _userColor) {
        _finish('won', moves);
      } else {
        _finish('lost', moves);
      }
      return;
    }
    if (g.in_draw) {
      _finish(goalKind == 'draw' ? 'won' : 'drawn', moves);
      return;
    }
    if (goalKind == 'promote' && userPromoted) {
      _finish('won', moves);
      return;
    }
    if (moves >= maxMoves) {
      _finish(goalKind == 'draw' ? 'won' : 'lost', moves);
    }
  }

  Future<void> _finish(String outcome, int moves) async {
    if (_reported) return;
    _reported = true;
    setState(() => _outcome = outcome);
    final completed = outcome == 'won' || (_goal['kind'] == 'draw' && outcome == 'drawn');
    try {
      await Api.instance.post('/endgames/progress', {
        'endgameId': widget.endgame['id'],
        'completed': completed,
        'moveCount': moves,
      });
    } on ApiError {
      // Best-effort; the session itself already played out fine.
    }
  }

  bool _attemptMove(String from, String to, String? promotion) {
    if (_outcome != 'playing' || _thinking || !_isUserTurn) return false;
    final g = ch.Chess.fromFEN(_fen, check_validity: false);
    final ok = g.move({'from': from, 'to': to, 'promotion': promotion ?? 'q'});
    if (!ok) return false;
    _moveCount++;
    setState(() {
      _fen = g.fen;
      _hintSquare = null;
    });
    _evaluate(g, _moveCount, userPromoted: promotion != null);
    if (!_reported) _engineTurn();
    return true;
  }

  Future<void> _engineTurn() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _thinking = true);
    final tier = reviewDepthFor(await Device.totalRamMb(), engineDepth: AppSettings.instance.engineDepth, batterySaver: AppSettings.instance.engineBatterySaver);
    final (best, _) = await engine.analyse(_fen, depth: tier.depth, movetimeMs: tier.movetimeMs, multiPv: 1);
    if (!mounted) return;
    final g = ch.Chess.fromFEN(_fen, check_validity: false);
    final ok = g.move({'from': best.substring(0, 2), 'to': best.substring(2, 4), 'promotion': best.length > 4 ? best[4] : 'q'});
    setState(() {
      _thinking = false;
      if (ok) _fen = g.fen;
    });
    if (ok) _evaluate(g, _moveCount);
  }

  Future<void> _requestHint() async {
    final engine = _engine;
    if (engine == null || _outcome != 'playing' || _thinking || !_isUserTurn) return;
    setState(() => _thinking = true);
    final (best, _) = await engine.analyse(_fen, depth: 18, movetimeMs: 400, multiPv: 1);
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _hintSquare = best.substring(0, 2);
    });
  }

  void _resign() {
    if (_outcome != 'playing') return;
    _finish('lost', _moveCount);
  }

  void _restart() {
    setState(() {
      _fen = widget.endgame['fen'] as String;
      _moveCount = 0;
      _outcome = 'playing';
      _hintSquare = null;
      _reported = false;
    });
    if (!_isUserTurn) _engineTurn();
  }

  String _goalSentence() {
    final maxMoves = (_goal['maxMoves'] as num).toInt();
    switch (_goal['kind']) {
      case 'mate':
        return 'Deliver mate within $maxMoves moves.';
      case 'promote':
        return 'Promote a pawn within $maxMoves moves.';
      case 'draw':
        return 'Hold the draw for $maxMoves moves.';
      default:
        return '';
    }
  }

  String _statusSentence() {
    switch (_outcome) {
      case 'won':
        return 'Well played -- goal reached!';
      case 'lost':
        return "Didn't make it this time.";
      case 'drawn':
        return 'Drawn -- not the goal here.';
      default:
        if (_thinking) return 'Engine is thinking...';
        return _isUserTurn ? 'Your move.' : "Engine's move...";
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final endgame = widget.endgame;
    return Scaffold(
      appBar: AppBar(title: Text(endgame['title'] as String)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HcSpace.s4),
          children: [
            Text(endgame['description'] as String? ?? '', style: HcText.body.copyWith(color: hc.ink2)),
            const SizedBox(height: 6),
            Text(_goalSentence(), style: HcText.bodySm.copyWith(color: hc.green)),
            const SizedBox(height: HcSpace.s3),
            if (_engineError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: HcSpace.s3),
                child: Text(_engineError!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
              ),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(HcRadius.board),
                child: ChessBoardView(
                  fen: _fen,
                  whiteAtBottom: _userColor == 'w',
                  hintSquare: _hintSquare,
                  onMove: _outcome == 'playing' && _isUserTurn && !_thinking ? _attemptMove : null,
                  animate: !AppSettings.instance.lowData,
                ),
              ),
            ),
            const SizedBox(height: HcSpace.s3),
            Text(_statusSentence(), style: HcText.titleMd.copyWith(color: hc.ink), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Move $_moveCount', style: HcText.bodySm.copyWith(color: hc.ink2), textAlign: TextAlign.center),
            const SizedBox(height: HcSpace.s3),
            if (_outcome == 'playing')
              Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                OutlinedButton(onPressed: _isUserTurn && !_thinking ? _requestHint : null, child: const Text('Hint')),
                OutlinedButton(onPressed: _restart, child: const Text('Reset')),
                OutlinedButton(onPressed: _resign, child: const Text('Give up')),
              ])
            else
              Center(
                child: FilledButton(onPressed: _restart, style: HcButtons.large(), child: const Text('Try again')),
              ),
            if ((endgame['hint'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: HcSpace.s4),
              Text('Hint', style: HcText.label.copyWith(color: hc.green)),
              const SizedBox(height: 4),
              Text(endgame['hint'] as String, style: HcText.bodySm.copyWith(color: hc.ink2)),
            ],
          ],
        ),
      ),
    );
  }
}
