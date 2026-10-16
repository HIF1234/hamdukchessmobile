import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/core/storage.dart';
import 'package:hamduk_chess/puzzles/puzzle_session.dart';
import 'package:hamduk_chess/puzzles/puzzle_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
      s.showHint();
      expect(s.hintFrom, 'd5');
      expect(s.hintTo, isNull); // one press only shows the source square
      s.tryMove('d5', 'c7');
      expect(s.awaitingReply, isTrue);
      s.playReply();
      expect(s.lastMove, ('e8', 'd8'));
      s.tryMove('c7', 'a8');
      expect(s.status, PuzzleStatus.solved);
    });

    test('a second hint press shows the full move; hint resets on the next move', () {
      final s = PuzzleSession(fork);
      expect(s.hintFrom, isNull); // nothing shown until asked
      s.showHint();
      expect(s.hintLevel, 1);
      s.showHint();
      expect(s.hintLevel, 2);
      expect(s.hintTo, 'c7');
      s.showHint(); // capped at 2
      expect(s.hintLevel, 2);
      s.tryMove('d5', 'c7');
      expect(s.hintLevel, 0); // fresh move, fresh hint
      expect(s.maxHintLevel, 2); // but the puzzle-wide max is remembered
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
    setUp(() {
      dir = Directory.systemTemp.createTempSync('hamduk');
      PuzzleStore.resetForTests();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('results queue on the device and survive a restart', () async {
      final json = JsonStore.at(dir);
      await json.write('puzzle_pack', {'puzzles': [mateIn1.toJson(), fork.toJson()], 'rating': 1200, 'maxPack': 30});
      final store = await PuzzleStore.open(json);
      expect(store.remaining, 2);
      await store.record(store.next!, true);

      PuzzleStore.resetForTests(); // as if the app had restarted
      final reopened = await PuzzleStore.open(json);
      expect(reopened.remaining, 1);
      expect(reopened.pendingUploads, 1);
      expect(reopened.next!.id, fork.id);
    });

    test('each theme keeps its own pack, but results share one upload queue', () async {
      final json = JsonStore.at(dir);
      await json.write('puzzle_pack_fork', {'puzzles': [fork.toJson()], 'rating': 1200, 'maxPack': 30});
      final rated = await PuzzleStore.open(json);
      final forks = await PuzzleStore.open(json, 'fork');
      expect(rated.remaining, 0);
      expect(forks.remaining, 1);
      await forks.record(forks.next!, true);
      expect(rated.pendingUploads, 1);
    });

    test('allowRefill: false uploads results but skips the pack top-up', () async {
      final json = JsonStore.at(dir);
      await json.write('puzzle_pack', {'puzzles': [mateIn1.toJson()], 'rating': 1200, 'maxPack': 30});
      final store = await PuzzleStore.open(json);
      await store.record(store.next!, true); // pack now empty, one result queued

      final calls = <String>[];
      Api.client = MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('/puzzles/sync')) {
          return http.Response(jsonEncode({'results': [{'status': 'recorded', 'rating': 1210}]}), 200);
        }
        return http.Response(jsonEncode({'puzzles': [fork.toJson()], 'rating': 1210, 'maxPack': 30}), 200);
      });
      addTearDown(() => Api.client = http.Client());

      final r = await store.sync(Api.instance, allowRefill: false);
      expect(r.uploaded, 1);
      expect(calls.any((p) => p.endsWith('/puzzles/pack')), isFalse);
      expect(store.remaining, 0); // no top-up happened

      final r2 = await store.sync(Api.instance); // allowRefill defaults to true
      expect(calls.any((p) => p.endsWith('/puzzles/pack')), isTrue);
      expect(store.remaining, 1);
      expect(r2.uploaded, 0); // nothing left queued the second time
    });
  });
}
