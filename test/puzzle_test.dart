import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/storage.dart';
import 'package:hamduk_chess/puzzles/puzzle_session.dart';
import 'package:hamduk_chess/puzzles/puzzle_store.dart';

// Back-rank mate in 1: Rd8#.
final mateIn1 = Puzzle(id: '00000000-0000-0000-0000-000000000001', fen: '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', solution: ['d1d8'], themes: ['mateIn1'], rating: 900);
// Three-ply line: 1.Nxc7+ Kd8 2.Nxa8 (a fork that wins the rook).
final fork = Puzzle(id: '00000000-0000-0000-0000-000000000002', fen: 'r3k3/pp3ppp/8/3N4/8/8/PP3PPP/4K3 w - - 0 1', solution: ['d5c7', 'e8d8', 'c7a8'], themes: ['fork'], rating: 1100);

void main() {
  group('PuzzleSession', () {
    test('the right move solves a one-move puzzle', () {
      final s = PuzzleSession(mateIn1);
      expect(s.tryMove('d1', 'd8'), isTrue);
      expect(s.status, PuzzleStatus.solved);
    });

    test('a legal wrong move fails, an illegal one is refused', () {
      final s = PuzzleSession(mateIn1);
      expect(s.tryMove('d1', 'd9'), isFalse);
      expect(s.status, PuzzleStatus.playing);
      expect(s.tryMove('d1', 'd7'), isTrue);
      expect(s.status, PuzzleStatus.failed);
    });

    test('multi-move lines wait for the scripted reply', () {
      final s = PuzzleSession(fork);
      expect(s.hint, 'd5');
      s.tryMove('d5', 'c7');
      expect(s.awaitingReply, isTrue);
      s.playReply();
      expect(s.lastMove, ('e8', 'd8'));
      s.tryMove('c7', 'a8');
      expect(s.status, PuzzleStatus.solved);
    });

    test('a promotion answer accepts the auto-queen', () {
      final p = Puzzle(id: 'x', fen: '8/P7/8/8/8/8/k7/4K3 w - - 0 1', solution: ['a7a8q'], themes: [], rating: 800);
      final s = PuzzleSession(p);
      s.tryMove('a7', 'a8', 'q');
      expect(s.status, PuzzleStatus.solved);
    });
  });

  group('PuzzleStore (offline)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('hamduk'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('results queue on the device and survive a restart', () async {
      final json = JsonStore.at(dir);
      await json.write('puzzle_pack', {'puzzles': [mateIn1.toJson(), fork.toJson()], 'rating': 1200, 'maxPack': 30});
      final store = await PuzzleStore.open(json);
      expect(store.remaining, 2);
      await store.record(store.next!, true);

      final reopened = await PuzzleStore.open(json);
      expect(reopened.remaining, 1);
      expect(reopened.pendingUploads, 1);
      expect(reopened.next!.id, fork.id);
    });
  });
}
