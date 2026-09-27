import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/engine/bot_brain.dart';
import 'package:hamduk_chess/engine/uci_engine.dart';

// The same Stockfish 11 source the phones get, built for this computer by engine/build.sh.
const hostEngine = 'engine/host/stockfish';
final haveEngine = File(hostEngine).existsSync();

const style = BotStyle(depthMin: 4, depthMax: 6, blunderRate: 0.1, randomness: 0.2, movetimeMs: 300, openingRepertoire: ['e2e4', 'd2d4']);

void main() {
  group('Stockfish over UCI', () {
    late UciEngine engine;
    setUp(() async => engine = await UciEngine.start(hostEngine));
    tearDown(() => engine.dispose());

    test('finds a mate in one', () async {
      final (best, lines) = await engine.analyse('6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', depth: 8, movetimeMs: 500);
      expect(best, 'd1d8');
      expect(lines.first.score, 100000);
    });

    test('returns three candidate lines, best first', () async {
      final (_, lines) = await engine.analyse('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', depth: 8, movetimeMs: 500);
      expect(lines.length, 3);
      expect(lines[0].score >= lines[1].score && lines[1].score >= lines[2].score, isTrue);
    });

    test('a bot plays a legal-looking move from a real position', () async {
      final move = await BotBrain(style, Random(1)).chooseMove(engine, 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2', 3);
      expect(move, matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')));
    });
  }, skip: haveEngine ? false : 'Run engine/build.sh first to build the test engine');

  group('bot move choice (same rules as the website)', () {
    const lines = [Pv('e2e4', 50), Pv('d2d4', 40), Pv('a2a3', -30)];

    test('White opens from the bot\'s repertoire', () async {
      final brain = BotBrain(style, Random(3));
      // No engine needed for book moves.
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        seen.add(await brain.chooseMove(_NoEngine(), 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 0));
      }
      expect(seen, {'e2e4', 'd2d4'});
    });

    test('a bot that never blunders and has no noise plays the best move', () {
      final perfect = BotBrain(const BotStyle(depthMin: 1, depthMax: 1, blunderRate: 0, randomness: 0, movetimeMs: 1), Random(1));
      for (var i = 0; i < 50; i++) {
        expect(perfect.pickFromPvs(lines), 'e2e4');
      }
    });

    test('a bot that always blunders never plays the best move', () {
      final blunderer = BotBrain(const BotStyle(depthMin: 1, depthMax: 1, blunderRate: 1, randomness: 0, movetimeMs: 1), Random(2));
      for (var i = 0; i < 50; i++) {
        expect(blunderer.pickFromPvs(lines), isNot('e2e4'));
      }
    });

    test('search depth stays in the bot\'s range', () {
      final b = BotBrain(style, Random(4));
      final depths = {for (var i = 0; i < 100; i++) b.pickDepth()};
      expect(depths, {4, 5, 6});
    });
  });
}

/// Stands in for the engine in book-move tests; must never be asked to search.
class _NoEngine implements UciEngine {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('the engine should not be used for book moves');
}
