import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../board/chess_board.dart';
import '../core/keep_screen_on.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../engine/device.dart';
import '../engine/uci_engine.dart';
import '../review/game_review.dart' show reviewDepthFor;
import 'board_editor_screen.dart';
import 'import_game_screen.dart';

const standardStartFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A free board with the engine on or off, three lines and the depth shown. Opened from
/// any game or position (e.g. review's "Open in Analysis"); [startFen] defaults to the
/// standard starting position.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, this.startFen = standardStartFen});
  final String startFen;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late ch.Chess _game = ch.Chess.fromFEN(widget.startFen, check_validity: false);
  final List<String> _sanHistory = [];
  UciEngine? _engine;
  String? _engineError;
  bool _engineOn = true;
  bool _analyzing = false;
  String? _pendingFen;
  List<Pv> _lines = [];
  int _depthReached = 0;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    KeepScreenOn.push();
    _startEngine();
  }

  Future<void> _startEngine() async {
    try {
      _engine = await UciEngine.start(await Device.stockfishPath());
      _requestAnalysis();
    } catch (e) {
      setState(() => _engineError = "The engine couldn't start on this phone.");
    }
  }

  @override
  void dispose() {
    KeepScreenOn.pop();
    _engine?.dispose();
    super.dispose();
  }

  void _requestAnalysis() {
    if (!_engineOn || _engine == null) return;
    _pendingFen = _game.fen;
    if (!_analyzing) _runAnalysisLoop();
  }

  Future<void> _runAnalysisLoop() async {
    final engine = _engine;
    if (engine == null) return;
    _analyzing = true;
    while (_pendingFen != null && _engineOn) {
      final fen = _pendingFen!;
      _pendingFen = null;
      final tier = reviewDepthFor(
        await Device.totalRamMb(),
        engineDepth: AppSettings.instance.engineDepth,
        batterySaver: AppSettings.instance.engineBatterySaver,
      );
      try {
        final (_, lines) = await engine.analyse(fen, depth: tier.depth, movetimeMs: tier.movetimeMs, multiPv: 3);
        if (mounted && fen == _game.fen) {
          setState(() {
            _lines = lines;
            _depthReached = tier.depth;
          });
        }
      } catch (_) {
        // Best-effort; the board itself still works without live lines.
      }
    }
    _analyzing = false;
  }

  bool _onMove(String from, String to, String? promo) {
    if (!_game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) return false;
    setState(() {
      _sanHistory.add(_game.getHistory().cast<String>().last);
      _lines = [];
    });
    _requestAnalysis();
    return true;
  }

  void _undo() {
    if (_sanHistory.isEmpty) return;
    setState(() {
      _game.undo();
      _sanHistory.removeLast();
      _lines = [];
    });
    _requestAnalysis();
  }

  void _reset() {
    setState(() {
      _game = ch.Chess.fromFEN(widget.startFen, check_validity: false);
      _sanHistory.clear();
      _lines = [];
    });
    _requestAnalysis();
  }

  void _toggleEngine(bool v) {
    setState(() => _engineOn = v);
    if (v) _requestAnalysis();
  }

  /// Up to [maxPly] of a principal variation, in SAN, for display ("1. Nf3 Nf6 2. c4").
  List<String> _pvSan(String fen, String pv, {int maxPly = 4}) {
    final g = ch.Chess.fromFEN(fen, check_validity: false);
    final out = <String>[];
    for (final uci in pv.split(' ').take(maxPly)) {
      if (uci.length < 4) break;
      final mv = g.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4), 'promotion': uci.length > 4 ? uci[4] : null});
      if (!mv) break;
      out.add(g.getHistory().cast<String>().last);
    }
    return out;
  }

  String _eval(int cp) {
    if (cp.abs() >= 90000) return cp > 0 ? 'White mates' : 'Black mates';
    final p = cp / 100;
    return '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final whiteToMove = _game.turn == ch.Color.WHITE;
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis board'), actions: [
        IconButton(
          tooltip: 'Board editor',
          icon: const Icon(Icons.grid_on_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoardEditorScreen())),
        ),
        IconButton(
          tooltip: 'Import a game',
          icon: const Icon(Icons.file_upload_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportGameScreen())),
        ),
      ]),
      body: SafeArea(
        top: false,
        child: _engineError != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_engineError!, textAlign: TextAlign.center)))
            : ListView(
                padding: const EdgeInsets.all(HcSpace.s4),
                children: [
                  Row(children: [
                    Expanded(child: Text(_sanHistory.isEmpty ? 'Starting position' : _sanHistory.join(' '))),
                    Switch(value: _engineOn, onChanged: _toggleEngine),
                    const SizedBox(width: HcSpace.s2),
                    Text(_engineOn ? 'Engine on' : 'Engine off', style: HcText.bodySm.copyWith(color: hc.ink2)),
                  ]),
                  const SizedBox(height: HcSpace.s2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(HcRadius.board),
                    child: ChessBoardView(
                      fen: _game.fen,
                      whiteAtBottom: !_flipped,
                      onMove: _onMove,
                      animate: !AppSettings.instance.lowData,
                    ),
                  ),
                  const SizedBox(height: HcSpace.s3),
                  Row(children: [
                    IconButton(onPressed: _sanHistory.isEmpty ? null : _undo, icon: const Icon(Icons.undo_rounded)),
                    IconButton(onPressed: () => setState(() => _flipped = !_flipped), icon: const Icon(Icons.swap_vert_rounded)),
                    IconButton(onPressed: _sanHistory.isEmpty ? null : _reset, icon: const Icon(Icons.replay_rounded)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _copyFen(context),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy FEN'),
                    ),
                  ]),
                  const SizedBox(height: HcSpace.s3),
                  if (_engineOn) ...[
                    Text(
                      _depthReached == 0 ? 'Thinking…' : 'Depth $_depthReached · ${whiteToMove ? 'White' : 'Black'} to move',
                      style: HcText.bodySm.copyWith(color: hc.ink2),
                    ),
                    const SizedBox(height: HcSpace.s2),
                    for (final (i, pv) in _lines.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(
                            width: 56,
                            child: Text(_eval(pv.score), style: HcText.titleSm.copyWith(color: i == 0 ? hc.green : hc.ink2)),
                          ),
                          Expanded(child: Text(_pvSan(_game.fen, pv.line).join(' '), style: HcText.bodySm.copyWith(color: hc.ink))),
                        ]),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  void _copyFen(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _game.fen));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FEN copied.')));
  }
}
