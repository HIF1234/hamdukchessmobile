import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'analysis_screen.dart';

const _glyph = {
  'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
  'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
};

/// Set up any position: tap a piece from the palette, then a square to place it (or the
/// eraser, then a square to clear it). Side to move, castling rights, a legality check and
/// "Copy FEN" -- opens straight into the Analysis board when the position's legal.
class BoardEditorScreen extends StatefulWidget {
  const BoardEditorScreen({super.key});

  @override
  State<BoardEditorScreen> createState() => _BoardEditorScreenState();
}

class _BoardEditorScreenState extends State<BoardEditorScreen> {
  Map<String, String> _placement = _placementFromFen(standardStartFen);
  String? _holding = 'K'; // currently selected palette piece; null = eraser
  bool _whiteToMove = true;
  final Set<String> _castling = {'K', 'Q', 'k', 'q'};
  String? _message;

  static Map<String, String> _placementFromFen(String fen) {
    final map = <String, String>{};
    final rows = fen.split(' ').first.split('/');
    for (var r = 0; r < 8; r++) {
      var f = 0;
      for (final ch in rows[r].split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          f += n;
        } else {
          map['${"abcdefgh"[f]}${8 - r}'] = ch;
          f++;
        }
      }
    }
    return map;
  }

  String get _fen {
    final rows = <String>[];
    for (var r = 8; r >= 1; r--) {
      var row = '';
      var gap = 0;
      for (final file in 'abcdefgh'.split('')) {
        final piece = _placement['$file$r'];
        if (piece == null) {
          gap++;
        } else {
          if (gap > 0) {
            row += '$gap';
            gap = 0;
          }
          row += piece;
        }
      }
      if (gap > 0) row += '$gap';
      rows.add(row);
    }
    final castling = _castling.isEmpty ? '-' : _castling.join();
    return '${rows.join('/')} ${_whiteToMove ? 'w' : 'b'} $castling - 0 1';
  }

  void _tapSquare(String square) => setState(() {
        _message = null;
        if (_holding == null) {
          _placement.remove(square);
        } else {
          _placement = {..._placement, square: _holding!};
        }
      });

  void _checkLegality() {
    try {
      ch.Chess.fromFEN(_fen, check_validity: true);
      setState(() => _message = 'Legal position.');
    } catch (e) {
      setState(() => _message = 'Not a legal position: $e');
    }
  }

  void _copyFen() {
    Clipboard.setData(ClipboardData(text: _fen));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FEN copied.')));
  }

  void _analyze() {
    try {
      ch.Chess.fromFEN(_fen, check_validity: true);
    } catch (_) {
      setState(() => _message = 'Fix the position before analyzing it -- it isn\'t legal yet.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnalysisScreen(startFen: _fen)));
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Board editor')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HcSpace.s4),
          children: [
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
                  final piece = _placement[square];
                  return GestureDetector(
                    onTap: () => _tapSquare(square),
                    child: Container(
                      color: light ? hc.surface2 : hc.surface3,
                      alignment: Alignment.center,
                      child: Text(piece != null ? _glyph[piece] ?? '' : '', style: const TextStyle(fontSize: 26)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: HcSpace.s3),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final p in 'KQRBNP'.split(''))
                _PaletteButton(piece: p, selected: _holding == p, onTap: () => setState(() => _holding = p)),
              for (final p in 'kqrbnp'.split(''))
                _PaletteButton(piece: p, selected: _holding == p, onTap: () => setState(() => _holding = p)),
              ChoiceChip(
                label: const Icon(Icons.backspace_outlined, size: 18),
                selected: _holding == null,
                onSelected: (_) => setState(() => _holding = null),
              ),
            ]),
            const SizedBox(height: HcSpace.s3),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('White to move')), ButtonSegment(value: false, label: Text('Black to move'))],
              selected: {_whiteToMove},
              onSelectionChanged: (s) => setState(() => _whiteToMove = s.first),
            ),
            const SizedBox(height: HcSpace.s3),
            Text('Castling rights', style: HcText.bodySm.copyWith(color: hc.ink2)),
            Wrap(spacing: 4, children: [
              for (final c in ['K', 'Q', 'k', 'q'])
                FilterChip(
                  label: Text(c),
                  selected: _castling.contains(c),
                  onSelected: (sel) => setState(() => sel ? _castling.add(c) : _castling.remove(c)),
                ),
            ]),
            const SizedBox(height: HcSpace.s3),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => setState(() => _placement = _placementFromFen(standardStartFen)), child: const Text('Starting position')),
              OutlinedButton(onPressed: () => setState(() => _placement = {}), child: const Text('Clear board')),
              OutlinedButton(onPressed: _checkLegality, child: const Text('Check legality')),
              OutlinedButton.icon(onPressed: _copyFen, icon: const Icon(Icons.copy_rounded, size: 16), label: const Text('Copy FEN')),
            ]),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: HcSpace.s2),
                child: Text(_message!, style: HcText.bodySm.copyWith(color: hc.ink2)),
              ),
            const SizedBox(height: HcSpace.s4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(style: HcButtons.large(), onPressed: _analyze, child: const Text('Analyze this position')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({required this.piece, required this.selected, required this.onTap});
  final String piece;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(_glyph[piece] ?? piece, style: const TextStyle(fontSize: 18)), selected: selected, onSelected: (_) => onTap());
  }
}
