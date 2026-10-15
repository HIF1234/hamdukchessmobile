import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../auth/guest_conversion.dart';
import '../board/chess_board.dart';
import '../core/game_feedback.dart';
import '../core/keep_screen_on.dart';
import '../core/notification_prompt.dart';
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
    this.initialWhiteMs,
    this.initialBlackMs,
  });
  final String gameId;
  final bool playWhite;
  final String opponentName;
  final String fen;
  final Stream<LocalMessage> messages;
  /// Null when the host wasn't tracking a clock for this game (shouldn't happen in practice,
  /// but the board still works untimed if so).
  final int? initialWhiteMs;
  final int? initialBlackMs;
  final void Function(String uci) sendMove;
  final void Function(String result) sendResult;

  @override
  State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen> {
  late final ch.Chess _game = ch.Chess.fromFEN(widget.fen, check_validity: false);
  StreamSubscription<LocalMessage>? _sub;
  (String, String)? _last;
  String? _lastSan;
  String? _over;
  bool _myConnectionLost = false;
  bool _opponentAway = false; // their socket dropped, but the host kept the game -- might resume
  late int? _whiteMs = widget.initialWhiteMs;
  late int? _blackMs = widget.initialBlackMs;

  @override
  void initState() {
    super.initState();
    KeepScreenOn.push();
    _sub = widget.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    KeepScreenOn.pop();
    _sub?.cancel();
    super.dispose();
  }

  void _onMessage(LocalMessage msg) {
    if (msg['type'] == 'disconnected') {
      // My own connection to the host dropped -- re-joining happens from the lobby screen, not
      // here, so just stop accepting moves and let the player back out.
      if (mounted && _over == null) setState(() => _myConnectionLost = true);
      return;
    }
    if (msg['gameId'] != widget.gameId) return;
    switch (msg['type']) {
      case 'move':
        final uci = msg['uci'] as String;
        if (!mounted) return;
        setState(() {
          _game.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4), 'promotion': uci.length > 4 ? uci[4] : null});
          _last = (uci.substring(0, 2), uci.substring(2, 4));
          _lastSan = _game.getHistory().cast<String>().last;
        });
        GameFeedback.on(eventForSan(_lastSan!, mine: false));
        _checkEnd();
      case 'opponent_left':
        if (mounted && _over == null) setState(() => _opponentAway = true);
      case 'opponent_back':
        if (mounted && _over == null) setState(() => _opponentAway = false);
      case 'clock':
        if (mounted) {
          setState(() {
            _whiteMs = msg['whiteMs'] as int?;
            _blackMs = msg['blackMs'] as int?;
          });
        }
      case 'result':
        // The host flagged someone out on time (we didn't detect it locally since only the
        // host's clock is authoritative) -- show the result it decided.
        if (mounted && _over == null) _finish(msg['result'] as String, 'time');
    }
  }

  bool _onMove(String from, String to, String? promo) {
    if (_over != null || _opponentAway || _myConnectionLost) return false;
    final whiteToMove = _game.turn == ch.Color.WHITE;
    if (whiteToMove != widget.playWhite) return false; // not this player's turn
    if (!_game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) return false;
    final san = _game.getHistory().cast<String>().last;
    GameFeedback.on(eventForSan(san, mine: true));
    setState(() {
      _last = (from, to);
      _lastSan = san;
    });
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await GuestConversion.gameFinished(context);
      if (mounted) await NotificationPrompt.gameFinished(context);
    });
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
            if (_whiteMs != null && _blackMs != null) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _ClockChip(label: widget.playWhite ? 'You' : widget.opponentName, ms: _whiteMs!, active: _game.turn == ch.Color.WHITE && _over == null),
                _ClockChip(label: !widget.playWhite ? 'You' : widget.opponentName, ms: _blackMs!, active: _game.turn == ch.Color.BLACK && _over == null),
              ]),
            ],
            const SizedBox(height: 8),
            ChessBoardView(
              fen: _game.fen,
              whiteAtBottom: widget.playWhite,
              playerColor: widget.playWhite ? 'w' : 'b',
              lastMove: _last,
              lastMoveSan: _lastSan,
              onMove: _over == null && !_opponentAway && !_myConnectionLost ? _onMove : null,
              animate: !AppSettings.instance.lowData,
            ),
            const SizedBox(height: 12),
            if (_myConnectionLost && _over == null) ...[
              Text('Connection to the host lost.', style: t.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to lobby')),
            ] else if (_opponentAway && _over == null) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('${widget.opponentName} disconnected -- waiting for them to reconnect…', style: t.textTheme.bodyMedium),
              ]),
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

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.label, required this.ms, required this.active});
  final String label;
  final int ms;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final totalSec = (ms / 1000).ceil().clamp(0, 1 << 30);
    final mm = totalSec ~/ 60;
    final ss = totalSec % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? t.colorScheme.primaryContainer : t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: t.textTheme.labelSmall?.copyWith(color: active ? t.colorScheme.onPrimaryContainer : t.colorScheme.onSurfaceVariant)),
        Text(
          '${mm.toString().padLeft(1, '0')}:${ss.toString().padLeft(2, '0')}',
          style: t.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: active ? t.colorScheme.onPrimaryContainer : t.colorScheme.onSurfaceVariant,
          ),
        ),
      ]),
    );
  }
}
