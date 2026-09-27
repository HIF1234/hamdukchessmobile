import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/engine/uci_engine.dart';
import 'package:hamduk_chess/review/game_review.dart';

const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
final haveEngine = File('engine/host/stockfish').existsSync();

void main() {
  test('move quality uses the website thresholds', () {
    expect(classify(0, false), Classification.best);
    expect(classify(300, true), Classification.best); // the engine's own move
    expect(classify(20, false), Classification.good);
    expect(classify(60, false), Classification.inaccuracy);
    expect(classify(150, false), Classification.mistake);
    expect(classify(250, false), Classification.blunder);
  });

  test('no loss is 100% accuracy; a big loss drags it down', () {
    MoveReview m(int before, int after) => MoveReview(
          ply: 1, san: 'x', uci: 'a1a2', white: true, fenBefore: start, fenAfter: start,
          evalBefore: before, evalAfter: after, bestMove: null, cpLoss: 0, classification: Classification.best);
    expect(accuracy([m(30, 30), m(30, 40)]), 100);
    expect(accuracy([m(0, -500)]), lessThan(30));
  });

  test('phone memory decides review depth', () {
    expect(reviewDepthFor(6000).depth, 14);
    expect(reviewDepthFor(3500).depth, 12);
    expect(reviewDepthFor(2000), (depth: 10, movetimeMs: 700, light: true));
  });

  test("reviews Scholar's Mate: Black's Nf6 is a blunder, White's Qxf7 is best", () async {
    final engine = await UciEngine.start('engine/host/stockfish');
    try {
      final r = (await reviewGame(engine,
          startFen: start,
          sanMoves: ['e4', 'e5', 'Bc4', 'Nc6', 'Qh5', 'Nf6', 'Qxf7#'],
          depth: 8,
          movetimeMs: 500))!;
      expect(r.moves.length, 7);
      expect(r.moves[5].san, 'Nf6');
      expect(r.moves[5].classification, Classification.blunder);
      expect(r.moves[6].classification, Classification.best);
      expect(r.moves[6].evalAfter, 100000); // White has mated
      expect(r.moves[5].bestSan, isNotNull); // e.g. g6 or Qe7
      expect(r.accuracyWhite, greaterThan(r.accuracyBlack));
    } finally {
      await engine.dispose();
    }
  }, skip: haveEngine ? false : 'Run engine/build.sh first');
}
