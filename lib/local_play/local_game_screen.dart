import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/settings.dart';
import 'local_network.dart';

/// One game between two phones on the same local hotspot, with moves relayed by the host
/// over [LocalTournamentHost]/[LocalTournamentClient] -- no internet, no server. Mirrors
/// bot_game_screen.dart's structure (chess package runs locally, board is read-only once the
/// game ends) but the "opponent" is a remote peer's moves arriving over [messages] instead of
/// an engine.
class LocalGameScreen extends StatefulWidget {
  const LocalGameScreen({
    super.key,
    required this.gameId,
    required this.playWhite,
    required this.opponentName,
    required this.fen,
    required this.messages,
    required this.sendMove,
    required this.sendResult,
  });
  final String gameId;
  final bool playWhite;
  final String opponentName;
  final String fen;
  final Stream<LocalMessage> messages;
  final void Function(String uci) sendMove;
  final void Function(String result) sendResult;

  @override
  State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen> {
  late final ch.Chess _game = ch.Chess.fromFEN(widget.fen, check_validity: false);
  StreamSubscription<LocalMessage>? _sub;
  (String, String)? _last;
  String? _over;
  bool _opponentLeft = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onMessage(LocalMessage msg) {
    if (msg['gameId'] != widget.gameId && msg['type'] != 'disconnected' && msg['type'] != 'bye') return;
    switch (msg['type']) {
      case 'move':
        final uci = msg['uci'] as String;
        if (!mounted) return;
        setState(() {
          _game.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4), 'promotion': uci.length > 4 ? uci[4] : null});
          _last = (uci.substring(0, 2), uci.substring(2, 4));
        });
        _checkEnd();
      case 'disconnected':
      case 'bye':
        if (mounted && _over == null) setState(() => _opponentLeft = true);
    }
  }

  bool _onMove(String from, String to, String? promo) {
    if (_over != null || _opponentLeft) return false;
    final whiteToMove = _game.turn == ch.Color.WHITE;
    if (whiteToMove != widget.playWhite) return false; // not this player's turn
    if (!_game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) return false;
    setState(() => _last = (from, to));
    widget.sendMove('$from$to${promo ?? ''}');
    _checkEnd();
    return true;
  }

  bool _checkEnd() {
    String? result;
    String? reasonText;
    if (_game.in_checkmate) {
      result = _game.turn == ch.Color.WHITE ? 'black' : 'white';
      reasonText = 'checkmate';
    } else if (_game.in_stalemate) {
      result = 'draw';
      reasonText = 'stalemate';
    } else if (_game.insufficient_material) {
      result = 'draw';
      reasonText = 'insufficient material';
    } else if (_game.in_threefold_repetition) {
      result = 'draw';
      reasonText = 'repetition';
    } else if (_game.in_draw) {
      result = 'draw';
      reasonText = '50-move rule';
    }
    if (result == null) return false;
    _finish(result, reasonText!);
    return true;
  }

  void _finish(String result, String reason) {
    setState(() {
      _over = switch (result) {
        'white' => widget.playWhite ? 'You win! ($reason)' : '${widget.opponentName} wins ($reason)',
        'black' => !widget.playWhite ? 'You win! ($reason)' : '${widget.opponentName} wins ($reason)',
        _ => 'Draw ($reason)',
      };
    });
    widget.sendResult(result);
  }

  void _resign() => _finish(widget.playWhite ? 'black' : 'white', 'resignation');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('vs ${widget.opponentName}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Local tournament · no data used', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            ChessBoardView(
              fen: _game.fen,
              whiteAtBottom: widget.playWhite,
              playerColor: widget.playWhite ? 'w' : 'b',
              lastMove: _last,
              onMove: _over == null && !_opponentLeft ? _onMove : null,
              animate: !AppSettings.instance.lowData,
            ),
            const SizedBox(height: 12),
            if (_opponentLeft && _over == null) ...[
              Text('${widget.opponentName} left the game.', style: t.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to lobby')),
            ] else if (_over != null) ...[
              Text(_over!, style: t.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to lobby')),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _resign, child: const Text('Resign')),
              ),
          ],
        ),
      ),
    );
  }
}
