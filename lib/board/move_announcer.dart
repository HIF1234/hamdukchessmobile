const _pieceNames = {'K': 'King', 'Q': 'Queen', 'R': 'Rook', 'B': 'Bishop', 'N': 'Knight'};

/// Full English name for a piece letter from a FEN/SAN ('K', 'q', ...); pawns have none in
/// SAN, so callers pass 'P' explicitly for a square's own piece.
String pieceName(String letter) => _pieceNames[letter.toUpperCase()] ?? 'Pawn';

/// A SAN move in words, for the screen reader and (later) read-aloud moves, e.g. "Knight
/// takes e5, check", "Castles kingside", "Pawn to e8, promoting to Queen, checkmate".
String announceSan(String san) {
  var s = san.trim();
  final checkmate = s.endsWith('#');
  final check = !checkmate && s.endsWith('+');
  final suffix = checkmate ? ', checkmate' : (check ? ', check' : '');
  s = s.replaceAll(RegExp(r'[+#]$'), '');
  if (s == 'O-O') return 'Castles kingside$suffix';
  if (s == 'O-O-O') return 'Castles queenside$suffix';

  var promotion = '';
  final promoMatch = RegExp(r'=([QRBN])$').firstMatch(s);
  if (promoMatch != null) {
    promotion = ', promoting to ${pieceName(promoMatch.group(1)!)}';
    s = s.substring(0, promoMatch.start);
  }
  final capture = s.contains('x');
  final pieceLetter = RegExp(r'^[KQRBN]').firstMatch(s)?.group(0);
  final piece = pieceLetter == null ? 'Pawn' : pieceName(pieceLetter);
  final dest = RegExp(r'[a-h][1-8]$').firstMatch(s)?.group(0) ?? '';
  return '$piece ${capture ? 'takes' : 'to'} $dest$promotion$suffix';
}
