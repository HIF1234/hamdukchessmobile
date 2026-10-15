import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';

const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

/// Centre of a square on a 400px board with White at the bottom (50px squares).
Offset at(String sq) {
  final file = sq.codeUnitAt(0) - 97;
  final rank = int.parse(sq[1]);
  return Offset(file * 50 + 25, (8 - rank) * 50 + 25);
}

/// A move handler that records moves and accepts them.
MoveHandler record(List<String> into) => (f, to, p) {
      into.add('$f$to');
      return true;
    };

Future<void> pump(WidgetTester t, Widget board) async {
  await t.pumpWidget(MaterialApp(home: Center(child: SizedBox(width: 400, height: 400, child: board))));
}

Future<void> tap(WidgetTester t, String sq) async {
  final origin = t.getTopLeft(find.byType(ChessBoardView));
  await t.tapAt(origin + at(sq));
  await t.pump();
}

void main() {
  testWidgets('tap a piece, then a legal square, plays the move', (t) async {
    final moves = <String>[];
    await pump(t, ChessBoardView(fen: start, playerColor: 'w', onMove: record(moves)));
    await tap(t, 'e2');
    await tap(t, 'e4');
    expect(moves, ['e2e4']);
  });

  testWidgets("an illegal square doesn't move; the opponent's pieces can't be picked", (t) async {
    final moves = <String>[];
    await pump(t, ChessBoardView(fen: start, playerColor: 'w', onMove: record(moves)));
    await tap(t, 'e2');
    await tap(t, 'e5'); // not legal for the e-pawn
    await tap(t, 'e7'); // Black's pawn
    await tap(t, 'e5');
    expect(moves, isEmpty);
  });

  testWidgets("during the opponent's turn a move becomes a premove", (t) async {
    final moves = <String>[];
    final premoves = <String>[];
    await pump(
      t,
      ChessBoardView(
        fen: afterE4, // Black to move; we are White
        playerColor: 'w',
        onMove: record(moves),
        onPremove: (f, to, p) => premoves.add('$f$to'),
      ),
    );
    await tap(t, 'g1');
    await tap(t, 'f3');
    expect(premoves, ['g1f3']);
    expect(moves, isEmpty);
  });

  testWidgets('a second piece can be queued behind the first, building a queue', (t) async {
    final premoves = <String>[];
    await pump(
      t,
      ChessBoardView(
        fen: afterE4,
        playerColor: 'w',
        onPremove: (f, to, p) => premoves.add('$f$to'),
        premoveQueue: const [('g1', 'f3')],
      ),
    );
    await tap(t, 'b1');
    await tap(t, 'c3');
    expect(premoves, ['b1c3']);
  });

  testWidgets("a square that's already the start of a queued premove can't be picked again", (t) async {
    final premoves = <String>[];
    await pump(
      t,
      ChessBoardView(
        fen: afterE4,
        playerColor: 'w',
        onPremove: (f, to, p) => premoves.add('$f$to'),
        premoveQueue: const [('g1', 'f3')],
      ),
    );
    await tap(t, 'g1');
    await tap(t, 'h3');
    expect(premoves, isEmpty);
  });

  testWidgets('tapping an empty square cancels the whole queue', (t) async {
    var cancelled = false;
    await pump(
      t,
      ChessBoardView(
        fen: afterE4,
        playerColor: 'w',
        onMove: (f, to, p) => false,
        onPremove: (f, to, p) {},
        onCancelPremove: () => cancelled = true,
        premoveQueue: const [('g1', 'f3'), ('b1', 'c3')],
      ),
    );
    await tap(t, 'd5');
    expect(cancelled, isTrue);
  });

  testWidgets('puzzles (no player colour) move whichever side is to play', (t) async {
    final moves = <String>[];
    await pump(t, ChessBoardView(fen: afterE4, onMove: record(moves)));
    await tap(t, 'e7');
    await tap(t, 'e5');
    expect(moves, ['e7e5']);
  });

  testWidgets('a pawn reaching the last rank shows a picker; queen first', (t) async {
    String? promo;
    await pump(
      t,
      ChessBoardView(fen: '8/P7/8/8/8/8/k7/4K3 w - - 0 1', playerColor: 'w', onMove: (f, to, p) {
        promo = p;
        return true;
      }),
    );
    await tap(t, 'a7');
    await tap(t, 'a8');
    expect(promo, isNull); // waits for a piece to be picked
    await tap(t, 'a8'); // the picker's first (queen) tile sits over the promotion square
    expect(promo, 'q');
  });

  testWidgets('a hint arrow renders without crashing and repaints on change', (t) async {
    await pump(t, const ChessBoardView(fen: start, arrow: ('e2', 'e4')));
    expect(find.byType(ChessBoardView), findsOneWidget);
    await pump(t, const ChessBoardView(fen: start, arrow: ('d2', 'd4')));
    expect(find.byType(ChessBoardView), findsOneWidget);
    await pump(t, const ChessBoardView(fen: start));
    expect(find.byType(ChessBoardView), findsOneWidget);
  });
}
