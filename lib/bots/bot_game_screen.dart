import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/settings.dart';
import '../core/telemetry.dart';
import '../engine/bot_brain.dart';
import '../engine/device.dart';
import '../engine/uci_engine.dart';
import '../review/review_screen.dart';
import 'bot_results.dart';

/// A game against one of the Naija bots, played entirely on the phone. Stockfish runs as a
/// separate program; no connection needed.
class BotGameScreen extends StatefulWidget {
  const BotGameScreen({super.key, required this.bot, required this.playWhite});
  final Map<String, dynamic> bot;
  final bool playWhite;

  @override
  State<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends State<BotGameScreen> {
  late ch.Chess _game = ch.Chess();
  late final BotBrain _brain = BotBrain(BotStyle.fromConfig((widget.bot['engine'] as Map).cast<String, dynamic>()));
  UciEngine? _engine;
  String? _engineError;
  bool _thinking = false;
  (String, String)? _last;
  String? _over; // result text once the game ends
  int _ply = 0;

  String get _name => widget.bot['name'] as String;

  @override
  void initState() {
    super.initState();
    _startEngine();
  }

  Future<void> _startEngine() async {
    try {
      _engine = await UciEngine.start(await Device.stockfishPath());
      if (!widget.playWhite) _botMove();
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
    if (_thinking || _over != null) return false;
    if (!_game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) return false;
    setState(() {
      _last = (from, to);
      _ply++;
    });
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
    _checkEnd();
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
      _over = switch (result) {
        'win' => 'You beat $_name! ($reason)',
        'loss' => '$_name wins ($reason)',
        _ => 'Draw ($reason)',
      };
    });
    BotResults.add({
      'timeControl': '5+0', // bot games are untimed; recorded the same way as on the website
      'variant': 'standard',
      'botId': widget.bot['id'],
      'result': result,
      'playerColor': widget.playWhite ? 'white' : 'black',
      'endReason': reason,
      'ply': _ply,
    }).then((_) => BotResults.sync());
  }

  void _newGame() {
    setState(() {
      _game = ch.Chess();
      _last = null;
      _over = null;
      _ply = 0;
    });
    if (!widget.playWhite) _botMove();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('vs $_name')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('${widget.bot['hometown']} · ${widget.bot['rating']}', style: t.textTheme.bodySmall),
            Text(_thinking ? '$_name is thinking…' : '“${widget.bot['catchphrase']}”', style: t.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (_engineError != null)
              Padding(padding: const EdgeInsets.all(24), child: Text(_engineError!, textAlign: TextAlign.center))
            else
              ChessBoardView(
                fen: _game.fen,
                whiteAtBottom: widget.playWhite,
                playerColor: widget.playWhite ? 'w' : 'b',
                lastMove: _last,
                onMove: _over == null && !_thinking ? _onMove : null,
                animate: !AppSettings.instance.lowData,
              ),
            const SizedBox(height: 12),
            if (_over != null) ...[
              Text(_over!, style: t.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _ply < 2
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                startFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                                sanMoves: _game.getHistory().cast<String>(),
                                whiteAtBottom: widget.playWhite,
                              ),
                            )),
                    child: const Text('Review'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: FilledButton(onPressed: _newGame, child: const Text('Play again'))),
              ]),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _ply < 2 ? null : () => _finish('loss', 'resignation'),
                  child: const Text('Resign'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
