import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/voice_move.dart';

const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

void main() {
  test('the three phrasings from the spec all resolve the same knight move', () {
    for (final heard in ['Knight f3', 'NF3', 'kNIGHT on g1 to f3']) {
      final m = parseVoiceMove(heard, start);
      expect(m.ok, isTrue, reason: heard);
      expect((m.from, m.to), ('g1', 'f3'), reason: heard);
    }
  });

  test('a plain destination defaults to a pawn move', () {
    final m = parseVoiceMove('e4', start);
    expect((m.from, m.to), ('e2', 'e4'));
  });

  test('"<square> to <square>" works for any piece', () {
    final m = parseVoiceMove('e2 to e4', start);
    expect((m.from, m.to), ('e2', 'e4'));
  });

  test('an ambiguous destination without a square asks to disambiguate', () {
    // Two queens that can both reach the same empty square (d8): one straight up the
    // d-file, one up the long diagonal from a5.
    const fen = '4k3/8/8/Q7/8/8/8/3Q3K w - - 0 1';
    final m = parseVoiceMove('queen d8', fen);
    expect(m.ok, isFalse);
    expect(m.error, contains('say which square'));
  });

  test('castling kingside and queenside', () {
    const fen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
    expect((parseVoiceMove('castle kingside', fen).from, parseVoiceMove('castle kingside', fen).to), ('e1', 'g1'));
    expect((parseVoiceMove('castle queenside', fen).from, parseVoiceMove('castle queenside', fen).to), ('e1', 'c1'));
  });

  test('promotion defaults to a queen when unspecified, honours an explicit piece', () {
    const fen = '8/P6k/8/8/8/8/7K/8 w - - 0 1';
    final def = parseVoiceMove('a8', fen);
    expect((def.from, def.to, def.promotion), ('a7', 'a8', 'q'));
    final knight = parseVoiceMove('a8 promoting to knight', fen);
    expect(knight.promotion, 'n');
  });

  test('an illegal move is rejected with a reason', () {
    final m = parseVoiceMove('e2 to e5', start);
    expect(m.ok, isFalse);
    expect(m.error, isNotNull);
  });

  test('gibberish is rejected rather than guessed at', () {
    final m = parseVoiceMove('what did you have for breakfast', start);
    expect(m.ok, isFalse);
  });

  test('works mid-game for the side actually to move', () {
    final m = parseVoiceMove('knight f6', afterE4); // Black's turn
    expect((m.from, m.to), ('g8', 'f6'));
  });
}
