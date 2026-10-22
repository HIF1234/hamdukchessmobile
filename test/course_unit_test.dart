import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/course_unit_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  void useTallSurface(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
  }

  Map<String, dynamic> unitWithQuiz() => {
        'id': 'pawn',
        'level': 1,
        'pieceName': 'Pawn',
        'title': 'The Board & Setup',
        'description': 'desc',
        'tutorialId': 'board-basics',
        'puzzleCount': 2,
        'minRating': 400,
        'maxRating': 700,
        'botId': 'army_legend',
        'quiz': [
          {'question': 'How many squares?', 'choices': ['32', '64'], 'correct': 1},
          {'question': 'Who moves first?', 'choices': ['White', 'Black'], 'correct': 0},
        ],
      };

  // A solved-in-one-move puzzle: white mates with Qg7 against a boxed-in black king.
  Map<String, dynamic> puzzle(String id) => {
        'id': id,
        'fen': '6k1/5ppp/8/6Q1/8/8/8/7K w - - 0 1',
        'solution': ['g5g7'],
        'themes': <String>[],
        'rating': 500,
      };

  MockClient client({List<Map<String, dynamic>> progress = const [], Map<String, dynamic>? markResponse}) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/course/progress' && request.method == 'GET') return http.Response(jsonEncode({'progress': progress}), 200);
      if (path == '/course/progress' && request.method == 'POST') {
        return http.Response(jsonEncode(markResponse ?? {'lesson_done': false, 'quiz_passed': true, 'puzzles_done': false, 'bot_beaten': false, 'completed': false}), 200);
      }
      if (path == '/puzzles/pack') {
        return http.Response(jsonEncode({'puzzles': [puzzle('p1'), puzzle('p2')]}), 200);
      }
      return http.Response('{}', 404);
    });
  }

  testWidgets('shows the four-part checklist', (t) async {
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: CourseUnitScreen(unit: unitWithQuiz())));
    await t.pumpAndSettle();
    expect(find.text('Lesson'), findsOneWidget);
    expect(find.text('Practice puzzles'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Beat the bot'), findsOneWidget);
  });

  testWidgets('passing the quiz (>=80%) marks the step done', (t) async {
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: CourseUnitScreen(unit: unitWithQuiz())));
    await t.pumpAndSettle();
    await t.tap(find.text('Quiz'));
    await t.pumpAndSettle();

    await t.tap(find.text('64'));
    await t.pump();
    await t.tap(find.text('Next'));
    await t.pump();
    await t.tap(find.text('White'));
    await t.pump();
    await t.tap(find.text('Finish'));
    await t.pump();
    expect(find.text('2 / 2 correct'), findsOneWidget);
    expect(find.text('Passed!'), findsOneWidget);

    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget); // the quiz row's done icon
  });

  testWidgets('failing the quiz does not mark the step done', (t) async {
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: CourseUnitScreen(unit: unitWithQuiz())));
    await t.pumpAndSettle();
    await t.tap(find.text('Quiz'));
    await t.pumpAndSettle();

    await t.tap(find.text('32')); // wrong
    await t.pump();
    await t.tap(find.text('Next'));
    await t.pump();
    await t.tap(find.text('Black')); // wrong
    await t.pump();
    await t.tap(find.text('Finish'));
    await t.pump();
    expect(find.text('0 / 2 correct'), findsOneWidget);
    expect(find.text('Not quite -- you need 80% to pass.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('practicing the full puzzle batch marks the step done', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(MaterialApp(home: CourseUnitScreen(unit: unitWithQuiz())));
    await t.pumpAndSettle();
    await t.tap(find.text('Practice puzzles'));
    await t.pumpAndSettle();
    expect(find.text('Puzzle 1 / 2'), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      final rect = t.getRect(find.byType(ChessBoardView));
      final size = rect.width / 8;
      Offset squareCenter(String sq) {
        final file = sq.codeUnitAt(0) - 97;
        final rank = int.parse(sq[1]);
        return rect.topLeft + Offset(file * size + size / 2, (8 - rank) * size + size / 2);
      }

      await t.tapAt(squareCenter('g5'));
      await t.pump();
      await t.tapAt(squareCenter('g7'));
      await t.pump();
      expect(find.text('Solved!'), findsOneWidget);
      await t.tap(find.text(i == 0 ? 'Next puzzle' : 'Finish'));
      await t.pumpAndSettle();
    }
    expect(find.byType(CourseUnitScreen), findsOneWidget);
  });
}
