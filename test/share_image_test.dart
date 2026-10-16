import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/games/game_state.dart';
import 'package:hamduk_chess/games/share_image.dart';

const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

GameState game({String? pgn}) => GameState(
      id: 'g1',
      white: const Player(id: 'w', username: 'Ade', rating: 1500, country: 'NG'),
      black: const Player(id: 'b', username: 'Bola', rating: 1480),
      status: 'completed',
      fen: start,
      pgn: pgn,
      ply: pgn == null ? 0 : 4,
      timeWhiteMs: 300000,
      timeBlackMs: 300000,
      lastClockUpdate: null,
      result: 'white',
      endReason: 'checkmate',
      winnerId: 'w',
    );

Future<BuildContext> pumpApp(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
  return t.element(find.byType(Scaffold));
}

void main() {
  testWidgets('captureShareImage produces a real PNG', (t) async {
    final context = await pumpApp(t);
    final bytes = await t.runAsync(() => captureShareImage(
          context,
          g: game(),
          whiteAtBottom: true,
          headline: 'Ade won',
          detail: 'By checkmate in 2 moves.',
        ));
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    // PNG signature.
    expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  });

  testWidgets('captureShareGif produces a real animated GIF', (t) async {
    final context = await pumpApp(t);
    final g = game(pgn: '1. e4 e5 2. Nf3 Nc6');
    final progressValues = <double>[];
    final bytes = await t.runAsync(
      () => captureShareGif(context, g: g, whiteAtBottom: true, onProgress: progressValues.add),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(100));
    // GIF signature.
    expect(String.fromCharCodes(bytes.sublist(0, 6)), anyOf('GIF87a', 'GIF89a'));
    expect(progressValues, isNotEmpty);
    expect(progressValues.last, 1.0);
  });

  testWidgets('captureShareGif returns null with no moves', (t) async {
    final context = await pumpApp(t);
    final bytes = await t.runAsync(() => captureShareGif(context, g: game(), whiteAtBottom: true));
    expect(bytes, isNull);
  });
}
