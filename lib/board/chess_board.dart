import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';

const _slide = Duration(milliseconds: 120);

/// Called when the player tries a move. Return true if it was accepted.
typedef MoveHandler = bool Function(String from, String to, String? promotion);

/// Called when the player queues a move during the opponent's turn.
typedef PremoveHandler = void Function(String from, String to, String? promotion);

/// A fast, dependency-light board: squares in one paint pass, pieces as cached SVGs placed
/// straight from the FEN. Tap a piece then a square, or drag. Pawns reaching the last rank
/// promote to a queen. Optionally slides the last move and takes premoves.
class ChessBoardView extends StatefulWidget {
  const ChessBoardView({
    super.key,
    required this.fen,
    this.whiteAtBottom = true,
    this.onMove,
    this.lastMove,
    this.hintSquare,
    this.playerColor,
    this.onPremove,
    this.onCancelPremove,
    this.premove,
    this.animate = true,
    this.arrow,
  });

  final String fen;
  final bool whiteAtBottom;

  /// Null makes the board read-only.
  final MoveHandler? onMove;
  final (String, String)? lastMove;
  final String? hintSquare;

  /// 'w' or 'b': the side this player controls. Null means whoever is to move (puzzles).
  final String? playerColor;

  /// When set, the player can queue a move while it's the opponent's turn.
  final PremoveHandler? onPremove;
  final VoidCallback? onCancelPremove;
  final (String, String)? premove;

  /// Slide the last move's piece. Off in low-data mode.
  final bool animate;

  /// A move to draw as an arrow (e.g. the second-tier puzzle hint).
  final (String, String)? arrow;

  @override
  State<ChessBoardView> createState() => _ChessBoardViewState();
}

class _ChessBoardViewState extends State<ChessBoardView> with SingleTickerProviderStateMixin {
  String? _selectedSq;
  Set<String> _targets = const {};
  bool _selectingPremove = false;
  String? _dragFrom;
  Offset? _dragPos;
  bool _droppedByHand = false;
  String? _promoFrom;
  String? _promoTo;
  bool _promoByHand = false;
  late final AnimationController _anim = AnimationController(vsync: this, duration: _slide, value: 1);

  @override
  void didUpdateWidget(ChessBoardView old) {
    super.didUpdateWidget(old);
    if (old.fen != widget.fen) {
      _clearSelection();
      // Slide the piece that just moved, unless the player dropped it there by hand.
      if (widget.animate && widget.lastMove != null && widget.lastMove != old.lastMove && !_droppedByHand) {
        _anim.forward(from: 0);
      } else {
        _anim.value = 1;
      }
      _droppedByHand = false;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String get _toMove => widget.fen.split(' ')[1];
  bool get _myTurn => widget.playerColor == null || widget.playerColor == _toMove;

  void _clearSelection() {
    _selectedSq = null;
    _targets = const {};
    _selectingPremove = false;
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

  /// A piece the player may pick up now: to move on their turn, or to premove otherwise.
  bool _canPick(String square) {
    final piece = _pieces[square];
    if (piece == null) return false;
    if (_myTurn) return widget.onMove != null && piece[0] == _toMove;
    return widget.onPremove != null && piece[0] == widget.playerColor;
  }

  void _select(String square) {
    if (_myTurn) {
      final game = ch.Chess.fromFEN(widget.fen, check_validity: false);
      final moves = game.moves({'square': square, 'verbose': true});
      setState(() {
        _selectedSq = square;
        _selectingPremove = false;
        _targets = {for (final m in moves) (m as Map)['to'] as String};
      });
    } else {
      // A premove is checked for legality only when it's played, since the position will
      // have changed by then. Any square not holding one of our own pieces is a candidate.
      final mine = widget.playerColor;
      setState(() {
        _selectedSq = square;
        _selectingPremove = true;
        _targets = {
          for (var f = 0; f < 8; f++)
            for (var r = 1; r <= 8; r++) '${'abcdefgh'[f]}$r'
        }..removeWhere((sq) => sq == square || (_pieces[sq]?.startsWith(mine ?? '-') ?? false));
      });
    }
  }

  void _tryMove(String from, String to, {bool byHand = false}) {
    final piece = _pieces[from];
    final isPromotion = piece != null && piece[1] == 'P' && (to[1] == '8' || to[1] == '1');
    if (_selectingPremove) {
      // Checked for legality only when it's actually played, so there's no board state yet
      // to show a picker against; default to a queen, same as before.
      widget.onPremove?.call(from, to, isPromotion ? 'q' : null);
      setState(_clearSelection);
      return;
    }
    if (isPromotion) {
      setState(() {
        _promoFrom = from;
        _promoTo = to;
        _promoByHand = byHand;
        _selectedSq = null;
        _targets = const {};
      });
      return;
    }
    _droppedByHand = byHand;
    widget.onMove?.call(from, to, null);
    setState(_clearSelection);
  }

  void _choosePromotion(String piece) {
    final from = _promoFrom!;
    final to = _promoTo!;
    _droppedByHand = _promoByHand;
    widget.onMove?.call(from, to, piece);
    setState(() {
      _promoFrom = null;
      _promoTo = null;
      _clearSelection();
    });
  }

  void _cancelPromotion() {
    setState(() {
      _promoFrom = null;
      _promoTo = null;
      _clearSelection();
    });
  }

  void _onTap(Offset p, double size) {
    if (widget.onMove == null && widget.onPremove == null) return;
    final sq = _squareAt(p, size);
    if (sq == null) return;
    if (_selectedSq != null && _targets.contains(sq)) {
      _tryMove(_selectedSq!, sq);
    } else if (_canPick(sq) && sq != _selectedSq) {
      _select(sq);
    } else {
      if (widget.premove != null && _selectedSq == null) widget.onCancelPremove?.call();
      setState(_clearSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = context.hcBoard;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final size = c.maxWidth;
        final sq = size / 8;
        final pieces = _pieces;
        return GestureDetector(
          onTapUp: _promoFrom != null ? null : (d) => _onTap(d.localPosition, size),
          onPanStart: _promoFrom != null || (widget.onMove == null && widget.onPremove == null)
              ? null
              : (d) {
                  final s = _squareAt(d.localPosition, size);
                  if (s != null && _canPick(s)) {
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
            if (from != null && to != null && to != from && _targets.contains(to)) {
              _tryMove(from, to, byHand: true);
            }
          },
          child: Stack(children: [
            CustomPaint(
              size: Size.square(size),
              painter: _SquaresPainter(
                board: board,
                whiteAtBottom: widget.whiteAtBottom,
                highlights: {
                  if (widget.lastMove != null) widget.lastMove!.$1: board.lastMove,
                  if (widget.lastMove != null) widget.lastMove!.$2: board.lastMove,
                  ?widget.hintSquare: board.selected,
                  if (widget.premove != null) widget.premove!.$1: board.premove,
                  if (widget.premove != null) widget.premove!.$2: board.premove,
                  ?_selectedSq: _selectingPremove ? board.premove : board.selected,
                },
                // A premove can go almost anywhere, so dots would only be noise.
                dots: _selectingPremove ? const {} : _targets,
                origin: (s) => _origin(s, size),
                squareSize: sq,
              ),
            ),
            for (final e in pieces.entries)
              if (e.key != _dragFrom)
                if (widget.lastMove != null && e.key == widget.lastMove!.$2)
                  // The piece that just moved slides from its old square.
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) {
                      final at = Offset.lerp(_origin(widget.lastMove!.$1, size), _origin(e.key, size),
                          Curves.easeOut.transform(_anim.value))!;
                      return Positioned(left: at.dx, top: at.dy, width: sq, height: sq, child: child!);
                    },
                    child: IgnorePointer(child: _PieceImage(e.value)),
                  )
                else
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
            if (widget.arrow != null)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _ArrowPainter(
                    color: board.arrow,
                    from: _origin(widget.arrow!.$1, size).translate(sq / 2, sq / 2),
                    to: _origin(widget.arrow!.$2, size).translate(sq / 2, sq / 2),
                    width: sq * 0.14,
                  ),
                ),
              ),
            if (_promoFrom != null && _promoTo != null)
              _PromotionPicker(
                white: _pieces[_promoFrom]!.startsWith('w'),
                origin: _origin(_promoTo!, size),
                squareSize: sq,
                boardSize: size,
                onPick: _choosePromotion,
                onCancel: _cancelPromotion,
              ),
          ]),
        );
      }),
    );
  }
}

/// Shown over the promotion square once a pawn reaches the last rank: queen, knight, rook
/// and bishop stacked toward the middle of the board so all four stay on it regardless of
/// orientation. Tapping outside cancels the move.
class _PromotionPicker extends StatelessWidget {
  const _PromotionPicker({
    required this.white,
    required this.origin,
    required this.squareSize,
    required this.boardSize,
    required this.onPick,
    required this.onCancel,
  });

  final bool white;
  final Offset origin;
  final double squareSize;
  final double boardSize;
  final ValueChanged<String> onPick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    // The promotion square sits on the board's top or bottom edge; stack the four choices
    // toward the middle so they never run off the board.
    final down = origin.dy < boardSize / 2;
    final color = white ? 'w' : 'b';
    const pieces = ['Q', 'N', 'R', 'B'];
    return Stack(children: [
      GestureDetector(
        onTap: onCancel,
        child: Container(width: boardSize, height: boardSize, color: Colors.black.withValues(alpha: 0.5)),
      ),
      for (final (i, piece) in pieces.indexed)
        Positioned(
          left: origin.dx,
          top: origin.dy + (down ? i : -i) * squareSize,
          width: squareSize,
          height: squareSize,
          child: DecoratedBox(
            decoration: BoxDecoration(color: hc.surface, boxShadow: HcShadows.e2(hc.brightness)),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => onPick(piece.toLowerCase()),
                child: _PieceImage('$color$piece'),
              ),
            ),
          ),
        ),
    ]);
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
    required this.board,
    required this.whiteAtBottom,
    required this.highlights,
    required this.dots,
    required this.origin,
    required this.squareSize,
  });

  final HcBoardTheme board;
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
        paint.color = (file + rank) % 2 == 0 ? board.dark : board.light;
        canvas.drawRect(rect, paint);
        final h = highlights[square];
        if (h != null) canvas.drawRect(rect, paint..color = h);
        if (dots.contains(square)) {
          canvas.drawCircle(rect.center, squareSize * 0.16, paint..color = board.moveDot);
        }
      }
    }
    // Coordinates along the bottom and left edges.
    final style = TextStyle(fontSize: squareSize * 0.18, fontWeight: FontWeight.w600);
    for (var i = 0; i < 8; i++) {
      final file = whiteAtBottom ? i : 7 - i;
      final rank = whiteAtBottom ? 7 - i : i;
      _label(canvas, 'abcdefgh'[file], Offset((i + 1) * squareSize - squareSize * 0.16, 8 * squareSize - squareSize * 0.24),
          style.copyWith(color: i % 2 == 0 ? board.light : board.dark));
      _label(canvas, '${rank + 1}', Offset(squareSize * 0.05, i * squareSize + squareSize * 0.03),
          style.copyWith(color: i % 2 == 0 ? board.dark : board.light));
    }
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SquaresPainter old) =>
      old.board.id != board.id ||
      old.whiteAtBottom != whiteAtBottom ||
      old.dots.length != dots.length ||
      !old.dots.containsAll(dots) ||
      old.highlights.toString() != highlights.toString();
}

/// A single arrow between two square centers (e.g. a hint move), lichess-style.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color, required this.from, required this.to, required this.width});
  final Color color;
  final Offset from;
  final Offset to;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final direction = to - from;
    final length = direction.distance;
    if (length < 1) return;
    final unit = direction / length;
    // Stop short of the target square's center so the arrowhead doesn't sit inside the piece.
    final headLength = width * 2.6;
    final shaftEnd = to - unit * headLength;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, shaftEnd, paint);

    final normal = Offset(-unit.dy, unit.dx);
    final headBase = to - unit * headLength;
    final p1 = headBase + normal * (width * 1.4);
    final p2 = headBase - normal * (width * 1.4);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color || old.from != from || old.to != to || old.width != width;
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
