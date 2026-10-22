import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/endgame_trainer_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  // The engine can't actually start in a widget test (no real Stockfish process/platform
  // channel), so _engine stays null and the opponent never replies -- fine for testing the
  // player's own move, the mate/goal evaluation, and give-up/restart, which don't need it.
  void useTallSurface(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
  }

  // Black king boxed in by its own pawns -- Re1-e8 is a clean back-rank mate in one.
  Map<String, dynamic> matingEndgame() => {
        'id': 'test-mate',
        'title': 'Back-rank mate drill',
        'description': 'Deliver mate on the back rank.',
        'category': 'basic-mates',
        'difficulty': 1,
        'fen': '6k1/5ppp/8/8/8/8/8/4R2K w - - 0 1',
        'userColor': 'white',
        'goal': {'kind': 'mate', 'maxMoves': 5},
        'hint': 'The rook alone delivers mate.',
      };

  MockClient client() {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/endgames/progress') return http.Response(jsonEncode({'attempts': 1, 'completed': true, 'best_move_count': 1}), 200);
      return http.Response('{}', 404);
    });
  }

  Future<void> tapSquare(WidgetTester t, String square) async {
    final rect = t.getRect(find.byType(ChessBoardView));
    final size = rect.width / 8;
    final file = square.codeUnitAt(0) - 97;
    final rank = int.parse(square[1]);
    final offset = rect.topLeft + Offset(file * size + size / 2, (8 - rank) * size + size / 2);
    await t.tapAt(offset);
    await t.pump();
  }

  testWidgets('shows the description, goal, and whose move it is', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: EndgameTrainerScreen(endgame: matingEndgame())));
    await t.pumpAndSettle();
    expect(find.text('Deliver mate on the back rank.'), findsOneWidget);
    expect(find.text('Deliver mate within 5 moves.'), findsOneWidget);
    expect(find.text('Your move.'), findsOneWidget);
  });

  testWidgets('delivering mate wins and reports progress', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: EndgameTrainerScreen(endgame: matingEndgame())));
    await t.pumpAndSettle();
    await tapSquare(t, 'e1');
    await tapSquare(t, 'e8');
    await t.pumpAndSettle();
    expect(find.text('Well played -- goal reached!'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Move 1'), findsOneWidget);
  });

  testWidgets('giving up resigns the drill', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: EndgameTrainerScreen(endgame: matingEndgame())));
    await t.pumpAndSettle();
    await t.tap(find.text('Give up'));
    await t.pumpAndSettle();
    expect(find.text("Didn't make it this time."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Try again resets the drill to the starting position', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: EndgameTrainerScreen(endgame: matingEndgame())));
    await t.pumpAndSettle();
    await t.tap(find.text('Give up'));
    await t.pumpAndSettle();
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Your move.'), findsOneWidget);
    expect(find.text('Move 0'), findsOneWidget);
    expect(find.text('Give up'), findsOneWidget);
  });
}
