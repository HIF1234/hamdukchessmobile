import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/bots/bot_game_screen.dart';

void main() {
  test('parses "min+inc" ids into (baseMs, incrementMs)', () {
    expect(parseBotTimeControl('5+0'), (300000, 0));
    expect(parseBotTimeControl('10+0'), (600000, 0));
    expect(parseBotTimeControl('15+10'), (900000, 10000));
  });

  test('null means untimed', () {
    expect(parseBotTimeControl(null), isNull);
  });

  test('malformed ids are treated as untimed rather than crashing', () {
    expect(parseBotTimeControl('garbage'), isNull);
    expect(parseBotTimeControl('5'), isNull);
    expect(parseBotTimeControl('a+b'), isNull);
  });

  test('flipTurnFen swaps the side to move and clears en passant', () {
    expect(
      flipTurnFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1'),
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
    );
    expect(
      flipTurnFen('6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1'),
      '6k1/5ppp/8/8/8/8/5PPP/3R2K1 b - - 0 1',
    );
  });
}
