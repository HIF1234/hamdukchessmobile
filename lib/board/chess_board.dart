import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _light = Color(0xFFF0D9B5);
const _dark = Color(0xFFB58863);
const _lastMove = Color(0x66F6D365);
const _selected = Color(0x8CF5A623);
const _dot = Color(0x59141414);

/// Called when the player tries a move. Return true if it was accepted.
typedef MoveHandler = bool Function(String from, String to, String? promotion);

/// A fast, dependency-light board: squares in one paint pass, pieces as cached SVGs placed
/// straight from the FEN. Tap a piece then a square, or drag. Pawns reaching the last rank
/// promote to a queen.
class ChessBoardView extends StatefulWidget {
  const ChessBoardView({
    super.key,
    required this.fen,
    this.whiteAtBottom = true,
    this.onMove,
    this.lastMove,
    this.hintSquare,
  });

  final String fen;
  final bool whiteAtBottom;

  /// Null makes the board read-only.
  final MoveHandler? onMove;
  final (String, String)? lastMove;
  final String? hintSquare;

  @override
  State<ChessBoardView> createState() => _ChessBoardViewState();
}

class _ChessBoardViewState extends State<ChessBoardView> {
  String? _selectedSq;
  Set<String> _targets = const {};
  String? _dragFrom;
  Offset? _dragPos;

  @override
  void didUpdateWidget(ChessBoardView old) {
    super.didUpdateWidget(old);
    if (old.fen != widget.fen) _clearSelection();
  }

  void _clearSelection() {
    _selectedSq = null;
    _targets = const {};
  }

  Map<String, String> get _pieces => _placement(widget.fen);

  String? _squareAt(Offset p, double size) {
    final sq = size / 8;
    final col = (p.dx / sq).floor();
    final row = (p.dy / sq).floor();
    if (col < 0 || col > 7 || row < 0 || row > 7) return null;
    final file = widget.whiteAtBottom ? col : 7 - col;
    final rank = widget.whiteAtBottom ? 7 - row : row;
    return '${'abcdefgh'[file]}${rank + 1}';
  }

  Offset _origin(String square, double size) {
    final sq = size / 8;
    final file = square.codeUnitAt(0) - 97;
    final rank = int.parse(square[1]) - 1;
    final col = widget.whiteAtBottom ? file : 7 - file;
    final row = widget.whiteAtBottom ? 7 - rank : rank;
    return Offset(col * sq, row * sq);
  }

  bool _isMine(String square) {
    final piece = _pieces[square];
    if (piece == null) return false;
    final whiteToMove = widget.fen.split(' ')[1] == 'w';
    return (piece[0] == 'w') == whiteToMove;
  }

  void _select(String square) {
    final game = ch.Chess.fromFEN(widget.fen, check_validity: false);
    final moves = game.moves({'square': square, 'verbose': true});
    setState(() {
      _selectedSq = square;
      _targets = {for (final m in moves) (m as Map)['to'] as String};
    });
  }

  bool _tryMove(String from, String to) {
    final piece = _pieces[from];
    final promo = piece != null && piece[1] == 'P' && (to[1] == '8' || to[1] == '1') ? 'q' : null;
    final ok = widget.onMove?.call(from, to, promo) ?? false;
    setState(_clearSelection);
    return ok;
  }

  void _onTap(Offset p, double size) {
    if (widget.onMove == null) return;
    final sq = _squareAt(p, size);
    if (sq == null) return;
    if (_selectedSq != null && _targets.contains(sq)) {
      _tryMove(_selectedSq!, sq);
    } else if (_isMine(sq) && sq != _selectedSq) {
      _select(sq);
    } else {
      setState(_clearSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final size = c.maxWidth;
        final sq = size / 8;
        final pieces = _pieces;
        return GestureDetector(
          onTapUp: (d) => _onTap(d.localPosition, size),
          onPanStart: widget.onMove == null
              ? null
              : (d) {
                  final s = _squareAt(d.localPosition, size);
                  if (s != null && _isMine(s)) {
                    _select(s);
                    setState(() {
                      _dragFrom = s;
                      _dragPos = d.localPosition;
                    });
                  }
                },
          onPanUpdate: (d) {
            if (_dragFrom != null) setState(() => _dragPos = d.localPosition);
          },
          onPanEnd: (_) {
            final from = _dragFrom;
            final to = _dragPos == null ? null : _squareAt(_dragPos!, size);
            setState(() {
              _dragFrom = null;
              _dragPos = null;
            });
            if (from != null && to != null && to != from && _targets.contains(to)) _tryMove(from, to);
          },
          child: Stack(children: [
            CustomPaint(
              size: Size.square(size),
              painter: _SquaresPainter(
                whiteAtBottom: widget.whiteAtBottom,
                highlights: {
                  if (widget.lastMove != null) widget.lastMove!.$1: _lastMove,
                  if (widget.lastMove != null) widget.lastMove!.$2: _lastMove,
                  ?widget.hintSquare: _selected,
                  ?_selectedSq: _selected,
                },
                dots: _targets,
                origin: (s) => _origin(s, size),
                squareSize: sq,
              ),
            ),
            for (final e in pieces.entries)
              if (e.key != _dragFrom)
                Positioned(
                  left: _origin(e.key, size).dx,
                  top: _origin(e.key, size).dy,
                  width: sq,
                  height: sq,
                  child: IgnorePointer(child: _PieceImage(e.value)),
                ),
            if (_dragFrom != null && _dragPos != null && pieces[_dragFrom] != null)
              Positioned(
                // Lifted a little above the finger so the player can see where it lands.
                left: _dragPos!.dx - sq * 0.6,
                top: _dragPos!.dy - sq * 1.1,
                width: sq * 1.2,
                height: sq * 1.2,
                child: IgnorePointer(child: _PieceImage(pieces[_dragFrom]!)),
              ),
          ]),
        );
      }),
    );
  }
}

class _PieceImage extends StatelessWidget {
  const _PieceImage(this.code);
  final String code; // e.g. wN

  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/pieces/$code.svg');
}

class _SquaresPainter extends CustomPainter {
  _SquaresPainter({
    required this.whiteAtBottom,
    required this.highlights,
    required this.dots,
    required this.origin,
    required this.squareSize,
  });

  final bool whiteAtBottom;
  final Map<String, Color> highlights;
  final Set<String> dots;
  final Offset Function(String) origin;
  final double squareSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final square = '${'abcdefgh'[file]}${rank + 1}';
        final o = origin(square);
        final rect = o & Size.square(squareSize);
        paint.color = (file + rank) % 2 == 0 ? _dark : _light;
        canvas.drawRect(rect, paint);
        final h = highlights[square];
        if (h != null) canvas.drawRect(rect, paint..color = h);
        if (dots.contains(square)) {
          canvas.drawCircle(rect.center, squareSize * 0.16, paint..color = _dot);
        }
      }
    }
    // Coordinates along the bottom and left edges.
    final style = TextStyle(fontSize: squareSize * 0.18, fontWeight: FontWeight.w600);
    for (var i = 0; i < 8; i++) {
      final file = whiteAtBottom ? i : 7 - i;
      final rank = whiteAtBottom ? 7 - i : i;
      _label(canvas, 'abcdefgh'[file], Offset((i + 1) * squareSize - squareSize * 0.16, 8 * squareSize - squareSize * 0.24),
          style.copyWith(color: i % 2 == 0 ? _light : _dark));
      _label(canvas, '${rank + 1}', Offset(squareSize * 0.05, i * squareSize + squareSize * 0.03),
          style.copyWith(color: i % 2 == 0 ? _dark : _light));
    }
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SquaresPainter old) =>
      old.whiteAtBottom != whiteAtBottom ||
      old.dots.length != dots.length ||
      !old.dots.containsAll(dots) ||
      old.highlights.toString() != highlights.toString();
}

/// Square -> piece code (e.g. "e1" -> "wK") from a FEN, without building a full game.
Map<String, String> _placement(String fen) {
  final out = <String, String>{};
  final rows = fen.split(' ').first.split('/');
  for (var r = 0; r < 8 && r < rows.length; r++) {
    var file = 0;
    for (final c in rows[r].split('')) {
      final n = int.tryParse(c);
      if (n != null) {
        file += n;
      } else {
        final white = c == c.toUpperCase();
        out['${'abcdefgh'[file]}${8 - r}'] = '${white ? 'w' : 'b'}${c.toUpperCase()}';
        file++;
      }
    }
  }
  return out;
}
