import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/opening_trainer_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  // The board (AspectRatio, square) takes most of the test window's default 800x600 size,
  // pushing the status text below the viewport's cache range -- find.byType skips offstage
  // widgets by default, so without more headroom it would see the board but not the text
  // below it, even though both are really in the tree (confirmed via allWidgets).
  void useTallSurface(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
  }

  Map<String, dynamic> twoPlyLine() => {
        'eco': 'TST',
        'name': 'Test Line',
        'color': 'white',
        'category': 'e4',
        'description': 'A short test line.',
        'ideas': ['Control the center'],
        'moves': ['e2e4', 'e7e5'],
      };

  MockClient client() {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/openings/progress') return http.Response(jsonEncode({'attempts': 1, 'correct': 1, 'mastered_depth': 2}), 200);
      return http.Response('{}', 404);
    });
  }

  /// Taps the center of [square] on the rendered ChessBoardView, wherever it landed.
  Future<void> tapSquare(WidgetTester t, String square) async {
    final rect = t.getRect(find.byType(ChessBoardView));
    final size = rect.width / 8;
    final file = square.codeUnitAt(0) - 97;
    final rank = int.parse(square[1]);
    final offset = rect.topLeft + Offset(file * size + size / 2, (8 - rank) * size + size / 2);
    await t.tapAt(offset);
    await t.pump();
  }

  testWidgets('shows whose move it is and the opening description', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: OpeningTrainerScreen(opening: twoPlyLine())));
    await t.pumpAndSettle();
    expect(find.text('A short test line.'), findsOneWidget);
    expect(find.textContaining("Your move"), findsOneWidget);
  });

  testWidgets('a wrong move is rejected and counts as an attempt', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: OpeningTrainerScreen(opening: twoPlyLine())));
    await t.pumpAndSettle();
    await tapSquare(t, 'd2'); // wrong piece for this line's first move
    await tapSquare(t, 'd4');
    await t.pump();
    expect(find.textContaining("Your move"), findsOneWidget); // still White to move, not advanced
  });

  testWidgets('three wrong attempts offers a hint', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: OpeningTrainerScreen(opening: twoPlyLine())));
    await t.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tapSquare(t, 'd2');
      await tapSquare(t, 'd4');
    }
    await t.pump();
    expect(find.text('Show a hint'), findsOneWidget);
  });

  testWidgets('playing the correct move advances and the opponent auto-plays the reply', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: OpeningTrainerScreen(opening: twoPlyLine())));
    await t.pumpAndSettle();
    await tapSquare(t, 'e2');
    await tapSquare(t, 'e4');
    await t.pump();
    expect(find.textContaining("Opponent's book move"), findsOneWidget);
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('1 / 1 correct this session'), findsOneWidget);
  });

  testWidgets('Play again resets the session', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: OpeningTrainerScreen(opening: twoPlyLine())));
    await t.pumpAndSettle();
    await tapSquare(t, 'e2');
    await tapSquare(t, 'e4');
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    await t.tap(find.text('Play again'));
    await t.pumpAndSettle();
    expect(find.textContaining("Your move"), findsOneWidget);
  });
}
