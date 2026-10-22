/// Unicode glyph for a FEN piece letter (uppercase white, lowercase black).
const pieceGlyph = {
  'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
  'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
};

/// The piece placement part of a FEN, as a `{square: pieceChar}` map (e.g. `'e4': 'P'`) --
/// uppercase for white, lowercase for black, same convention `package:chess` uses.
Map<String, String> placementFromFen(String fen) {
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
