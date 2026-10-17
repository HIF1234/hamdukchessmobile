import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../auth/guest_conversion.dart';
import '../board/chess_board.dart';
import '../core/game_feedback.dart';
import '../core/hc_widgets.dart';
import '../core/keep_screen_on.dart';
import '../core/notification_prompt.dart';
import '../core/settings.dart';
import '../core/telemetry.dart';
import '../core/theme.dart';
import '../core/active_game.dart';
import '../engine/bot_brain.dart';
import '../engine/device.dart';
import '../engine/uci_engine.dart';
import '../review/review_screen.dart';
import 'bot_results.dart';

/// Parses a "min+inc" id ("5+0", "15+10") into (baseMs, incrementMs). Null for untimed.
(int, int)? parseBotTimeControl(String? id) {
  if (id == null) return null;
  final parts = id.split('+');
  if (parts.length != 2) return null;
  final min = int.tryParse(parts[0]);
  final inc = int.tryParse(parts[1]);
  if (min == null || inc == null) return null;
  return (min * 60000, inc * 1000);
}

/// The same position with the side to move flipped -- a "null move" probe: what would the
/// opponent play if it were their turn right now, instead of mine? Clears en passant since
/// that right doesn't carry over to a position that was never actually reached this way.
String flipTurnFen(String fen) {
  final parts = fen.split(' ');
  if (parts.length < 4) return fen;
  parts[1] = parts[1] == 'w' ? 'b' : 'w';
  parts[3] = '-';
  return parts.join(' ');
}

/// A game against one of the Naija bots, played entirely on the phone. Stockfish runs as a
/// separate program; no connection needed.
class BotGameScreen extends StatefulWidget {
  const BotGameScreen({
    super.key,
    required this.bot,
    required this.playWhite,
    this.initialSanMoves,
    this.startFen,
    this.autoHint = false,
    this.assistedMode = true,
    this.timeControl,
    this.initialWhiteMs,
    this.initialBlackMs,
  });
  final Map<String, dynamic> bot;
  final bool playWhite;
  /// When resuming a game the app closed mid-way through (see [ActiveGame]).
  final List<String>? initialSanMoves;
  /// "Play from a position" (analysis/review or a finished lesson). Null starts from the
  /// standard position. [initialSanMoves], if also set, replay on top of this.
  final String? startFen;
  /// Shows a hint arrow as soon as the engine is ready, unprompted -- for a brand-new
  /// player's very first move, right after onboarding.
  final bool autoHint;

  /// Takebacks, the hint button, and hanging-piece highlights. On by default; a win with
  /// it off is what counts toward the bot ladder.
  final bool assistedMode;

  /// "5+0", "10+0", "15+10", or null for untimed (the default).
  final String? timeControl;
  /// Resumed clock state (see [ActiveGame]); null starts both sides at the base time.
  final int? initialWhiteMs;
  final int? initialBlackMs;

  @override
  State<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends State<BotGameScreen> {
  late ch.Chess _game = widget.startFen != null ? ch.Chess.fromFEN(widget.startFen!, check_validity: false) : ch.Chess();
  late final BotBrain _brain = BotBrain(BotStyle.fromConfig((widget.bot['engine'] as Map).cast<String, dynamic>()));
  UciEngine? _engine;
  String? _engineError;
  bool _thinking = false;
  bool _hintLoading = false;
  (String, String)? _last;
  String? _lastSan;
  (String, String)? _hintMove;
  String? _hangingSquare; // assisted mode: one of my own pieces, undefended and attacked
  bool _flipped = false;
  String? _result; // win | loss | draw, once the game ends
  String? _reason;
  int _ply = 0;
  int? _preMoveScore; // the opponent's eval of the position just before my move, for blunder detection
  String? _botLine; // a personality line, shown in place of the bot's status briefly

  bool get _pidgin => AppSettings.instance.language == 'pcm';

  late int? _baseMs;
  late int _incMs;
  int? _whiteMs;
  int? _blackMs;
  Timer? _clockTimer;

  String get _name => widget.bot['name'] as String;
  int get _rating => (widget.bot['rating'] as num).toInt();

  @override
  void initState() {
    super.initState();
    KeepScreenOn.push();
    final tc = parseBotTimeControl(widget.timeControl);
    _baseMs = tc?.$1;
    _incMs = tc?.$2 ?? 0;
    if (_baseMs != null) {
      _whiteMs = widget.initialWhiteMs ?? _baseMs;
      _blackMs = widget.initialBlackMs ?? _baseMs;
      _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tickClock());
    }
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

  void _tickClock() {
    if (_result != null) return;
    final white = _game.turn == ch.Color.WHITE;
    final ms = white ? _whiteMs! - 250 : _blackMs! - 250;
    setState(() {
      if (white) {
        _whiteMs = ms;
      } else {
        _blackMs = ms;
      }
    });
    if (ms <= 0) {
      setState(() {
        if (white) {
          _whiteMs = 0;
        } else {
          _blackMs = 0;
        }
      });
      final playerFlagged = white == widget.playWhite;
      _finish(playerFlagged ? 'loss' : 'win', 'timeout');
    }
  }

  /// Keeps [ActiveGame] in sync so the app can resume here if it's closed mid-game.
  void _rememberProgress() {
    ActiveGame.setBot(
      botId: widget.bot['id'] as String,
      playWhite: widget.playWhite,
      sanMoves: _game.getHistory().cast<String>(),
      assisted: widget.assistedMode,
      startFen: widget.startFen,
      timeControl: widget.timeControl,
      whiteMs: _whiteMs,
      blackMs: _blackMs,
    );
  }

  Future<void> _startEngine() async {
    try {
      _engine = await UciEngine.start(await Device.stockfishPath());
      if (_result == null && (_game.turn == ch.Color.WHITE) != widget.playWhite) {
        _botMove();
      } else if (widget.autoHint && _ply == 0) {
        _showHint();
      } else {
        _checkHangingPieces();
      }
    } catch (e, st) {
      Telemetry.recordError(e, st, reason: 'engine start');
      setState(() => _engineError = "The bot engine couldn't start on this phone.");
    }
  }

  @override
  void dispose() {
    KeepScreenOn.pop();
    _engine?.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  /// Fischer increment, added to the side that just moved.
  void _addIncrement(bool whiteJustMoved) {
    if (_baseMs == null || _incMs == 0) return;
    if (whiteJustMoved) {
      _whiteMs = _whiteMs! + _incMs;
    } else {
      _blackMs = _blackMs! + _incMs;
    }
  }

  bool _onMove(String from, String to, String? promo) {
    if (_thinking || _result != null) return false;
    if (!_game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) return false;
    final san = _game.getHistory().cast<String>().last;
    GameFeedback.on(eventForSan(san, mine: true));
    setState(() {
      _last = (from, to);
      _lastSan = san;
      _hintMove = null;
      _hangingSquare = null;
      _botLine = null;
      _ply++;
      _addIncrement(widget.playWhite);
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
    final preMoveScore = _preMoveScore;
    final (uci, postMoveScore) = await _brain.chooseMove(engine, _game.fen, _ply);
    // A short pause so instant replies from weak bots don't feel robotic.
    final spent = DateTime.now().difference(started);
    if (spent < const Duration(milliseconds: 400)) await Future.delayed(const Duration(milliseconds: 400) - spent);
    if (!mounted) return;
    _game.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4), 'promotion': uci.length > 4 ? uci[4] : null});
    final san = _game.getHistory().cast<String>().last;
    GameFeedback.on(eventForSan(san, mine: false));
    // The player's own blunder, not the bot's -- a cpLoss jump between the opponent's eval
    // of the position just before vs just after the player's move (both from the same,
    // non-mover side's point of view, so they're directly comparable).
    final cpLoss = (preMoveScore != null && postMoveScore != null) ? postMoveScore - preMoveScore : 0;
    setState(() {
      _last = (uci.substring(0, 2), uci.substring(2, 4));
      _lastSan = san;
      _ply++;
      _thinking = false;
      _addIncrement(!widget.playWhite);
      if (cpLoss >= 200) _botLine = _pidgin ? widget.bot['blunderLinePidgin'] as String? : widget.bot['blunderLine'] as String?;
    });
    _rememberProgress();
    if (!_checkEnd()) _checkHangingPieces();
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

  /// Assisted mode: flags one of the player's own pieces if it's undefended and the
  /// opponent would win material by taking it, right now, before the player's next move.
  Future<void> _checkHangingPieces() async {
    if (_result != null || _hintLoading || _thinking) return;
    final engine = _engine;
    if (engine == null) return;
    setState(() => _hintLoading = true); // shares the engine with Hint; never runs both at once
    try {
      final (best, lines) = await engine.analyse(flipTurnFen(_game.fen), depth: 10, movetimeMs: 300, multiPv: 1);
      if (!mounted || _result != null) return;
      final score = lines.isEmpty ? 0 : lines.first.score;
      // Captured regardless of assistedMode: it's also the "before" baseline for live
      // blunder detection, which happens whether or not the highlight itself is shown.
      _preMoveScore = score;
      if (!widget.assistedMode) return;
      final to = best.substring(2, 4);
      final targetIsMine = _game.get(to) != null && (_game.get(to)!.color == ch.Color.WHITE) == widget.playWhite;
      setState(() => _hangingSquare = targetIsMine && score >= 150 ? to : null);
    } catch (_) {
      // Best-effort highlight; nothing else depends on it.
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
      _botLine = null;
      final hist = _game.getHistory({'verbose': true});
      _last = hist.isEmpty ? null : ((hist.last as Map)['from'] as String, (hist.last as Map)['to'] as String);
      final sanHist = _game.getHistory().cast<String>();
      _lastSan = sanHist.isEmpty ? null : sanHist.last;
    });
    _rememberProgress();
    _checkHangingPieces();
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
    if (_result != null) return; // the clock timer can race a move/resign that already ended it
    GameFeedback.on(GameEvent.gameEnd);
    _clockTimer?.cancel();
    final wonByCheckmate = result == 'loss' && reason == 'checkmate';
    setState(() {
      _result = result;
      _reason = reason;
      _hintMove = null;
      _hangingSquare = null;
      _botLine = wonByCheckmate ? (_pidgin ? widget.bot['checkmateLinePidgin'] as String? : widget.bot['checkmateLine'] as String?) : null;
    });
    ActiveGame.clear();
    BotResults.add({
      // Untimed bot games are recorded as '5+0' too, same convention as the website.
      'timeControl': widget.timeControl ?? '5+0',
      'variant': 'standard',
      'botId': widget.bot['id'],
      'result': result,
      'playerColor': widget.playWhite ? 'white' : 'black',
      'endReason': reason,
      'ply': _ply,
      'assisted': widget.assistedMode,
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
      _game = widget.startFen != null ? ch.Chess.fromFEN(widget.startFen!, check_validity: false) : ch.Chess();
      _last = null;
      _lastSan = null;
      _hintMove = null;
      _hangingSquare = null;
      _botLine = null;
      _preMoveScore = null;
      _result = null;
      _reason = null;
      _ply = 0;
      if (_baseMs != null) {
        _whiteMs = _baseMs;
        _blackMs = _baseMs;
      }
    });
    if (_baseMs != null) {
      _clockTimer?.cancel();
      _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tickClock());
    }
    _rememberProgress();
    if (!widget.playWhite) {
      _botMove();
    } else {
      _checkHangingPieces();
    }
  }

  String get _headline => switch (_result) {
        'win' => 'You won.',
        'loss' => 'You lost.',
        _ => 'Draw.',
      };

  String get _detail => switch (_reason) {
        'checkmate' => _result == 'win'
            ? 'By checkmate against $_name.'
            : '$_name wins by checkmate. “$_botLine”',
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
                        startFen: widget.startFen ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
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
    if (!mounted) return;
    await GuestConversion.gameFinished(context);
    if (mounted) await NotificationPrompt.gameFinished(context);
  }

  Widget _clockWidget(bool white) {
    if (_baseMs == null) return const _UntimedPill();
    final ms = white ? _whiteMs! : _blackMs!;
    return GameClock(ms: ms, active: _result == null && _game.turn == (white ? ch.Color.WHITE : ch.Color.BLACK));
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
                    status: _thinking
                        ? '$_name is thinking…'
                        : _botLine != null
                            ? '“$_botLine”'
                            : (_ply == 0 ? '“${_pidgin ? widget.bot['catchphrasePidgin'] : widget.bot['catchphrase']}”' : null),
                    clock: _clockWidget(!widget.playWhite),
                  ),
                  ChessBoardView(
                    fen: _game.fen,
                    whiteAtBottom: widget.playWhite != _flipped,
                    playerColor: widget.playWhite ? 'w' : 'b',
                    lastMove: _last,
                    lastMoveSan: _lastSan,
                    arrow: _hintMove,
                    dangerSquare: _hangingSquare,
                    onMove: _result == null && !_thinking ? _onMove : null,
                    animate: !AppSettings.instance.lowData,
                  ),
                  PlayerBar(name: 'You', clock: _clockWidget(widget.playWhite)),
                ],
              ),
      ),
      bottomNavigationBar: _engineError != null
          ? null
          : GameActionBar(actions: [
              if (widget.assistedMode)
                GameAction(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Hint',
                  onTap: _result == null && !_thinking && !_hintLoading ? _showHint : null,
                ),
              if (widget.assistedMode)
                GameAction(
                  icon: Icons.undo_rounded,
                  label: 'Take back',
                  onTap: _result == null && !_thinking && _ply >= 2 ? _takeBack : null,
                ),
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
