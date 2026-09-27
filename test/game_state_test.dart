import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/games/game_state.dart';

const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

GameState game({String fen = start, int ply = 0, int w = 300000, int b = 300000, DateTime? last, String status = 'active', String? pgn}) =>
    GameState(
      id: 'g',
      white: const Player(id: 'W', username: 'ade', rating: 1500),
      black: const Player(id: 'B', username: 'bola', rating: 1480),
      status: status,
      fen: fen,
      pgn: pgn,
      ply: ply,
      timeWhiteMs: w,
      timeBlackMs: b,
      lastClockUpdate: last,
    );

void main() {
  group('clocks', () {
    final t0 = DateTime.utc(2026, 9, 26, 12);

    test('the side to move counts down from the server update', () {
      // Ply 2 (after 1.e4 e5): White to move, 10s since the last clock update.
      final g = game(fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2', ply: 2, last: t0);
      final (w, b) = displayClocks(g, now: t0.add(const Duration(seconds: 10)), serverOffset: Duration.zero);
      expect(w, 290000);
      expect(b, 300000);
    });

    test("a phone clock that's 30s slow is corrected by the server offset", () {
      final g = game(fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2', ply: 2, last: t0);
      final phoneNow = t0.add(const Duration(seconds: 10)).subtract(const Duration(seconds: 30));
      final (w, _) = displayClocks(g, now: phoneNow, serverOffset: const Duration(seconds: 30));
      expect(w, 290000);
    });

    test("clocks don't run before each side has moved, or after the game", () {
      expect(displayClocks(game(ply: 1, last: t0), now: t0.add(const Duration(minutes: 1)), serverOffset: Duration.zero),
          (300000, 300000));
      expect(
          displayClocks(game(ply: 20, last: t0, status: 'completed'),
              now: t0.add(const Duration(minutes: 1)), serverOffset: Duration.zero),
          (300000, 300000));
    });

    test('never below zero', () {
      final g = game(fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2', ply: 2, w: 1000, last: t0);
      final (w, _) = displayClocks(g, now: t0.add(const Duration(minutes: 5)), serverOffset: Duration.zero);
      expect(w, 0);
    });
  });

  group('moves', () {
    test('a legal move is prepared with the next ply', () {
      final m = prepareMove(game(ply: 0), 'e2', 'e4', null)!;
      expect(m.uci, 'e2e4');
      expect(m.ply, 1);
      expect(m.fenAfter.split(' ').first, 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR');
    });

    test('an illegal move is never prepared', () {
      expect(prepareMove(game(), 'e2', 'e5', null), isNull);
      expect(prepareMove(game(), 'e7', 'e5', null), isNull); // not our piece
    });

    test('promotions carry the chosen piece; other moves do not', () {
      final g = game(fen: '8/P7/8/8/8/8/k7/4K3 w - - 0 1', ply: 40);
      expect(prepareMove(g, 'a7', 'a8', null)!.uci, 'a7a8q');
      expect(prepareMove(g, 'a7', 'a8', 'n')!.uci, 'a7a8n');
      expect(prepareMove(g, 'e1', 'd1', null)!.uci, 'e1d1');
    });
  });

  test('a Realtime update keeps player names and replaces the position', () {
    final g = game().mergeRow({'fen': 'x w - - 0 1', 'ply': 1, 'status': 'active'});
    expect(g.white.username, 'ade');
    expect(g.fen, 'x w - - 0 1');
    expect(g.ply, 1);
  });

  test('all moves are read from the PGN for review', () {
    expect(game(pgn: '1. e4 e5 2. Nf3 Nc6').sanMoves, ['e4', 'e5', 'Nf3', 'Nc6']);
    expect(game(pgn: null).sanMoves, isEmpty);
  });

  test('the last move is read from the PGN', () {
    expect(game(pgn: '1. e4 e5 2. Nf3').lastMove, ('g1', 'f3'));
    expect(game(pgn: null).lastMove, isNull);
  });
}
