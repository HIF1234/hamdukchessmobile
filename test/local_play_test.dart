import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/local_play/local_network.dart';
import 'package:hamduk_chess/local_play/pairing.dart';

void main() {
  group('LocalTournamentHost + LocalTournamentClient over a real local socket', () {
    late LocalTournamentHost host;
    String? ip;

    setUp(() async {
      host = LocalTournamentHost();
      ip = await host.start();
    });

    tearDown(() => host.stop());

    test('a client joining gets a clientId and appears in the lobby', () async {
      if (ip == null) return; // no network interface in this CI sandbox; skip gracefully
      final client = LocalTournamentClient();
      final welcome = client.messages.firstWhere((m) => m['type'] == 'welcome');
      final ok = await client.connect(ip!, 'ade');
      expect(ok, isTrue);
      final msg = await welcome.timeout(const Duration(seconds: 3));
      expect(msg['clientId'], isNotNull);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(host.players, hasLength(1));
      expect(host.players.first.username, 'ade');
      await client.disconnect();
    });

    test('two clients get paired and relay moves to each other, not the host', () async {
      if (ip == null) return;
      final white = LocalTournamentClient();
      final black = LocalTournamentClient();
      await white.connect(ip!, 'white-player');
      await black.connect(ip!, 'black-player');
      await Future.delayed(const Duration(milliseconds: 150));
      expect(host.players, hasLength(2));

      final whiteId = host.players.firstWhere((p) => p.username == 'white-player').id;
      final blackId = host.players.firstWhere((p) => p.username == 'black-player').id;

      final whitePairing = white.messages.firstWhere((m) => m['type'] == 'pairing');
      final blackPairing = black.messages.firstWhere((m) => m['type'] == 'pairing');
      final gameId = host.startGame(whiteId, blackId);

      final wp = await whitePairing.timeout(const Duration(seconds: 3));
      final bp = await blackPairing.timeout(const Duration(seconds: 3));
      expect(wp['color'], 'white');
      expect(wp['opponent'], 'black-player');
      expect(bp['color'], 'black');
      expect(bp['opponent'], 'white-player');
      expect(wp['gameId'], gameId);

      final blackReceivesMove = black.messages.firstWhere((m) => m['type'] == 'move');
      white.send({'type': 'move', 'gameId': gameId, 'uci': 'e2e4'});
      final received = await blackReceivesMove.timeout(const Duration(seconds: 3));
      expect(received['uci'], 'e2e4');

      await white.disconnect();
      await black.disconnect();
    });

    test('a result is only counted once even if both players report it', () async {
      if (ip == null) return;
      final white = LocalTournamentClient();
      final black = LocalTournamentClient();
      await white.connect(ip!, 'w');
      await black.connect(ip!, 'b');
      await Future.delayed(const Duration(milliseconds: 150));
      final whiteId = host.players.firstWhere((p) => p.username == 'w').id;
      final blackId = host.players.firstWhere((p) => p.username == 'b').id;
      final gameId = host.startGame(whiteId, blackId);
      await Future.delayed(const Duration(milliseconds: 50));

      final results = <(String, String, String, String)>[];
      host.results.listen(results.add);

      white.send({'type': 'result', 'gameId': gameId, 'result': 'white'});
      black.send({'type': 'result', 'gameId': gameId, 'result': 'white'}); // duplicate report
      await Future.delayed(const Duration(milliseconds: 150));

      expect(results, hasLength(1));
      expect(results.first.$4, 'white');

      await white.disconnect();
      await black.disconnect();
    });

    test('a disconnected player is removed from the lobby', () async {
      if (ip == null) return;
      final client = LocalTournamentClient();
      await client.connect(ip!, 'leaving');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(host.players, hasLength(1));
      await client.disconnect();
      await Future.delayed(const Duration(milliseconds: 150));
      expect(host.players, isEmpty);
    });

    test('rejects a username that is currently connected', () async {
      if (ip == null) return;
      final first = LocalTournamentClient();
      await first.connect(ip!, 'dupe');
      await Future.delayed(const Duration(milliseconds: 100));

      final second = LocalTournamentClient();
      final rejected = second.messages.firstWhere((m) => m['type'] == 'name_taken');
      await second.connect(ip!, 'dupe');
      await expectLater(rejected.timeout(const Duration(seconds: 2)), completes);

      await first.disconnect();
      await second.disconnect();
    });

    test(
      'a player who drops mid-game gets the current position back on reconnect, and their '
      'opponent is told they left and then came back',
      () async {
        if (ip == null) return;
        final white = LocalTournamentClient();
        final black = LocalTournamentClient();
        await white.connect(ip!, 'w');
        await black.connect(ip!, 'b');
        await Future.delayed(const Duration(milliseconds: 150));
        final gameId = host.startGame('w', 'b');
        await Future.delayed(const Duration(milliseconds: 50));

        // White plays e4; the host now has a board that isn't the start position any more.
        white.send({'type': 'move', 'gameId': gameId, 'uci': 'e2e4'});
        await Future.delayed(const Duration(milliseconds: 100));

        final blackToldLeft = black.messages.firstWhere((m) => m['type'] == 'opponent_left');
        await white.disconnect();
        final leftMsg = await blackToldLeft.timeout(const Duration(seconds: 2));
        expect(leftMsg['gameId'], gameId);

        // White reconnects with the same username -- should get the post-e4 position back.
        final whiteAgain = LocalTournamentClient();
        final resumed = whiteAgain.messages.firstWhere((m) => m['type'] == 'pairing');
        final blackToldBack = black.messages.firstWhere((m) => m['type'] == 'opponent_back');
        await whiteAgain.connect(ip!, 'w');
        final resumedMsg = await resumed.timeout(const Duration(seconds: 2));
        expect(resumedMsg['gameId'], gameId);
        expect(resumedMsg['color'], 'white');
        expect(resumedMsg['fen'], isNot(kStartFen)); // reflects the e4 already played
        await blackToldBack.timeout(const Duration(seconds: 2));

        await whiteAgain.disconnect();
        await black.disconnect();
      },
    );
  });

  group('pairRound', () {
    test('pairs an even number of players by score, strongest meeting strongest', () {
      final a = LocalStanding('a', 'Ade')..points = 2;
      final b = LocalStanding('b', 'Bola')..points = 2;
      final c = LocalStanding('c', 'Chidi')..points = 1;
      final d = LocalStanding('d', 'Dupe')..points = 0;
      final pairings = pairRound([a, b, c, d]);
      expect(pairings, hasLength(2));
      expect(pairings[0].whiteId, 'a');
      expect(pairings[0].blackId, 'b');
      expect(pairings[1].whiteId, 'c');
      expect(pairings[1].blackId, 'd');
    });

    test('an odd number of players gives the last one a bye', () {
      final a = LocalStanding('a', 'Ade');
      final b = LocalStanding('b', 'Bola');
      final c = LocalStanding('c', 'Chidi');
      final pairings = pairRound([a, b, c]);
      expect(pairings, hasLength(2));
      expect(pairings.last.blackId, isNull);
    });

    test('avoids a rematch when a same-score alternative exists', () {
      final a = LocalStanding('a', 'A')..opponents.add('b');
      final b = LocalStanding('b', 'B')..opponents.add('a');
      final c = LocalStanding('c', 'C');
      final pairings = pairRound([a, b, c]);
      final first = pairings.first;
      expect({first.whiteId, first.blackId}, isNot({'a', 'b'}));
    });
  });

  group('applyResult', () {
    test('a decisive result awards one point to the winner', () {
      final white = LocalStanding('w', 'White');
      final black = LocalStanding('b', 'Black');
      final byId = {'w': white, 'b': black};
      applyResult(byId, 'w', 'b', 'white');
      expect(white.points, 1);
      expect(black.points, 0);
      expect(white.games, 1);
      expect(black.games, 1);
      expect(white.opponents, contains('b'));
    });

    test('a draw awards half a point each', () {
      final white = LocalStanding('w', 'White');
      final black = LocalStanding('b', 'Black');
      final byId = {'w': white, 'b': black};
      applyResult(byId, 'w', 'b', 'draw');
      expect(white.points, 0.5);
      expect(black.points, 0.5);
    });

    test('a bye awards one point with no opponent recorded', () {
      final white = LocalStanding('w', 'White');
      final byId = {'w': white};
      applyResult(byId, 'w', null, 'bye');
      expect(white.points, 1);
      expect(white.opponents, isEmpty);
    });
  });
}
