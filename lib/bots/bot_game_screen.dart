import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/telemetry.dart';
import '../core/theme.dart';
import '../core/active_game.dart';
import '../engine/bot_brain.dart';
import '../engine/device.dart';
import '../engine/uci_engine.dart';
import '../review/review_screen.dart';
import 'bot_results.dart';

/// A game against one of the Naija bots, played entirely on the phone. Stockfish runs as a
/// separate program; no connection needed.
class BotGameScreen extends StatefulWidget {
  const BotGameScreen({super.key, required this.bot, required this.playWhite, this.initialSanMoves});
  final Map<String, dynamic> bot;
  final bool playWhite;
  /// When resuming a game the app closed mid-way through (see [ActiveGame]).
  final List<String>? initialSanMoves;

  @override
  State<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends State<BotGameScreen> {
  late ch.Chess _game = ch.Chess();
  late final BotBrain _brain = BotBrain(BotStyle.fromConfig((widget.bot['engine'] as Map).cast<String, dynamic>()));
  UciEngine? _engine;
  String? _engineError;
  bool _thinking = false;
  bool _hintLoading = false;
  (String, String)? _last;
  (String, String)? _hintMove;
  bool _flipped = false;
  String? _result; // win | loss | draw, once the game ends
  String? _reason;
  int _ply = 0;

  String get _name => widget.bot['name'] as String;
  int get _rating => (widget.bot['rating'] as num).toInt();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSanMoves;
    if (initial != null) {
      for (final san in initial) {
        _game.move(san);
      }
      _ply = initial.length;
      final hist = _game.getHistory({'verbose': true});
      _last = hist.isEmpty ? null : ((hist.last as Map)['from'] as String, (hist.last as Map)['to'] as String);
    }
    _rememberProgress();
    _startEngine();
  }

  /// Keeps [ActiveGame] in sync so the app can resume here if it's closed mid-game.
  void _rememberProgress() {
    ActiveGame.setBot(botId: widget.bot['id'] as String, playWhite: widget.playWhite, sanMoves: _game.getHistory().cast<String>());
  }

  Future<void> _startEngine() async {
    try {
      _engine = await UciEngine.start(await Device.stockfishPath());
      if (_result == null && (_game.turn == ch.Color.WHITE) != widget.playWhite) _botMove();
    } catch (e, st) {
      Telemetry.recordError(e, st, reason: 'engine start');
      setState(() => _engineError = "The bot engine couldn't start on this phone.");
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  bool _onMove(String from, String to, String? promo) {
    if (_thinking || _result != null) return false;
    if (!_game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) return false;
    setState(() {
      _last = (from, to);
      _hintMove = null;
      _ply++;
    });
    _rememberProgress();
    if (!_checkEnd()) _botMove();
    return true;
  }

  Future<void> _botMove() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _thinking = true);
    final started = DateTime.now();
    final uci = await _brain.chooseMove(engine, _game.fen, _ply);
    // A short pause so instant replies from weak bots don't feel robotic.
    final spent = DateTime.now().difference(started);
    if (spent < const Duration(milliseconds: 400)) await Future.delayed(const Duration(milliseconds: 400) - spent);
    if (!mounted) return;
    _game.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4), 'promotion': uci.length > 4 ? uci[4] : null});
    setState(() {
      _last = (uci.substring(0, 2), uci.substring(2, 4));
      _ply++;
      _thinking = false;
    });
    _rememberProgress();
    _checkEnd();
  }

  /// A hint from the same engine, at the player's own position, between their moves.
  Future<void> _showHint() async {
    final engine = _engine;
    if (engine == null || _thinking || _result != null || _hintLoading) return;
    setState(() => _hintLoading = true);
    try {
      final (best, _) = await engine.analyse(_game.fen, depth: 12, movetimeMs: 500, multiPv: 1);
      if (mounted) setState(() => _hintMove = (best.substring(0, 2), best.substring(2, 4)));
    } finally {
      if (mounted) setState(() => _hintLoading = false);
    }
  }

  void _takeBack() {
    if (_thinking || _result != null || _ply < 2) return;
    setState(() {
      _game.undo(); // the bot's reply
      _game.undo(); // the player's move
      _ply -= 2;
      _hintMove = null;
      final hist = _game.getHistory({'verbose': true});
      _last = hist.isEmpty ? null : ((hist.last as Map)['from'] as String, (hist.last as Map)['to'] as String);
    });
    _rememberProgress();
  }

  /// Ends the game if the position is over. Returns true when it did.
  bool _checkEnd() {
    String? result;
    String? reason;
    final playerToMove = (_game.turn == ch.Color.WHITE) == widget.playWhite;
    if (_game.in_checkmate) {
      result = playerToMove ? 'loss' : 'win';
      reason = 'checkmate';
    } else if (_game.in_stalemate) {
      result = 'draw';
      reason = 'stalemate';
    } else if (_game.insufficient_material) {
      result = 'draw';
      reason = 'insufficient material';
    } else if (_game.in_threefold_repetition) {
      result = 'draw';
      reason = 'repetition';
    } else if (_game.in_draw) {
      result = 'draw';
      reason = '50-move rule';
    }
    if (result == null) return false;
    _finish(result, reason!);
    return true;
  }

  void _finish(String result, String reason) {
    setState(() {
      _result = result;
      _reason = reason;
      _hintMove = null;
    });
    ActiveGame.clear();
    BotResults.add({
      'timeControl': '5+0', // bot games are untimed; recorded the same way as on the website
      'variant': 'standard',
      'botId': widget.bot['id'],
      'result': result,
      'playerColor': widget.playWhite ? 'white' : 'black',
      'endReason': reason,
      'ply': _ply,
    }).then((_) => BotResults.sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
  }

  Future<void> _confirmResign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resign this game?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep playing')),
          FilledButton(style: HcButtons.danger(ctx), onPressed: () => Navigator.pop(ctx, true), child: const Text('Resign')),
        ],
      ),
    );
    if (ok == true) _finish('loss', 'resignation');
  }

  void _newGame() {
    setState(() {
      _game = ch.Chess();
      _last = null;
      _hintMove = null;
      _result = null;
      _reason = null;
      _ply = 0;
    });
    _rememberProgress();
    if (!widget.playWhite) _botMove();
  }

  String get _headline => switch (_result) {
        'win' => 'You won.',
        'loss' => 'You lost.',
        _ => 'Draw.',
      };

  String get _detail => switch (_reason) {
        'checkmate' => _result == 'win' ? 'By checkmate against $_name.' : '$_name wins by checkmate.',
        'stalemate' => 'By stalemate.',
        'insufficient material' => 'By insufficient material.',
        'repetition' => 'By repetition.',
        '50-move rule' => 'By the fifty-move rule.',
        'resignation' => 'By resignation.',
        _ => '',
      };

  Future<void> _showResult() async {
    if (!mounted) return;
    final canReview = _ply >= 2;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final hc = ctx.hc;
        return Container(
          decoration: BoxDecoration(color: hc.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(HcRadius.lg))),
          child: ResultSheet(
            overline: 'Game over · vs $_name',
            headline: _headline,
            detail: _detail,
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: HcButtons.large(),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _newGame();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Play again'),
                ),
              ),
              if (canReview)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReviewScreen(
                        startFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                        sanMoves: _game.getHistory().cast<String>(),
                        whiteAtBottom: widget.playWhite,
                      ),
                    )),
                    child: const Text('Review'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Choose another bot'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('vs $_name')),
      body: SafeArea(
        top: false,
        child: _engineError != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_engineError!, textAlign: TextAlign.center)))
            : Column(
                children: [
                  const SizedBox(height: HcSpace.s2),
                  PlayerBar(
                    name: _name,
                    rating: _rating,
                    avatar: HcAvatar(
                      name: _name,
                      stage: hcStageFor(_rating),
                      imageUrl: AppSettings.instance.lowData ? null : widget.bot['portraitUrl'] as String?,
                    ),
                    status: _thinking ? '$_name is thinking…' : (_ply == 0 ? '“${widget.bot['catchphrase']}”' : null),
                    clock: const _UntimedPill(),
                  ),
                  ChessBoardView(
                    fen: _game.fen,
                    whiteAtBottom: widget.playWhite != _flipped,
                    playerColor: widget.playWhite ? 'w' : 'b',
                    lastMove: _last,
                    arrow: _hintMove,
                    onMove: _result == null && !_thinking ? _onMove : null,
                    animate: !AppSettings.instance.lowData,
                  ),
                  const PlayerBar(name: 'You', clock: _UntimedPill()),
                ],
              ),
      ),
      bottomNavigationBar: _engineError != null
          ? null
          : GameActionBar(actions: [
              GameAction(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Hint',
                onTap: _result == null && !_thinking && !_hintLoading ? _showHint : null,
              ),
              GameAction(icon: Icons.undo_rounded, label: 'Take back', onTap: _result == null && !_thinking && _ply >= 2 ? _takeBack : null),
              GameAction(icon: Icons.swap_vert_rounded, label: 'Flip', onTap: () => setState(() => _flipped = !_flipped)),
              GameAction(icon: Icons.flag_rounded, label: 'Resign', onTap: _result == null && _ply >= 2 ? _confirmResign : null),
            ]),
    );
  }
}

/// The clock slot for a PlayerBar in an untimed bot game.
class _UntimedPill extends StatelessWidget {
  const _UntimedPill();

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(color: hc.surface2, borderRadius: BorderRadius.circular(HcRadius.xs)),
      child: Text('Untimed', style: HcText.bodySm.copyWith(color: hc.ink2)),
    );
  }
}
