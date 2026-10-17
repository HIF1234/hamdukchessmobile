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
}
