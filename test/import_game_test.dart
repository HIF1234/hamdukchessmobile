import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/analysis/import_game_screen.dart';

void main() {
  test('a FEN is recognised by its 8 placement ranks', () {
    expect(looksLikeFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'), isTrue);
    expect(looksLikeFen('6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1'), isTrue);
  });

  test('PGN, SAN and plain text are not mistaken for a FEN', () {
    expect(looksLikeFen('1. e4 e5 2. Nf3 Nc6'), isFalse);
    expect(looksLikeFen('e4 e5 Nf3 Nc6'), isFalse);
    expect(looksLikeFen('[Event "Casual game"]\n1. e4 e5'), isFalse);
    expect(looksLikeFen(''), isFalse);
  });
}
