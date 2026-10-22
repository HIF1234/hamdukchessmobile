import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/course_path_screen.dart';
import 'package:hamduk_chess/learn/course_unit_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  Map<String, dynamic> unit(int level, String id, String piece) => {
        'id': id,
        'level': level,
        'pieceName': piece,
        'title': 'Unit $level',
        'description': 'desc',
        'tutorialId': 'tut-$id',
        'puzzleCount': 5,
        'minRating': 400,
        'maxRating': 700,
        'botId': 'army_legend',
        'quiz': [
          {'question': 'Q1', 'choices': ['A', 'B'], 'correct': 0},
        ],
      };

  List<Map<String, dynamic>> units() => [
        unit(1, 'pawn', 'Pawn'),
        unit(2, 'knight', 'Knight'),
      ];

  MockClient client({List<Map<String, dynamic>> progress = const []}) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/course') return http.Response(jsonEncode({'units': units()}), 200);
      if (path == '/course/progress' && request.method == 'GET') return http.Response(jsonEncode({'progress': progress}), 200);
      return http.Response('{}', 404);
    });
  }

  testWidgets('lists units in order with lock state based on the previous unit', (t) async {
    Api.client = client();
    await t.pumpWidget(const MaterialApp(home: CoursePathScreen()));
    await t.pumpAndSettle();
    expect(find.text('Pawn -- Unit 1'), findsOneWidget);
    expect(find.text('Knight -- Unit 2'), findsOneWidget);
    expect(find.text('Finish the level before this one to unlock'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('a completed first unit unlocks the second', (t) async {
    Api.client = client(progress: [
      {'unit_id': 'pawn', 'lesson_done': true, 'quiz_passed': true, 'puzzles_done': true, 'bot_beaten': true, 'completed_at': '2026-01-01T00:00:00Z'},
    ]);
    await t.pumpWidget(const MaterialApp(home: CoursePathScreen()));
    await t.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    await t.tap(find.text('Knight -- Unit 2'));
    await t.pumpAndSettle();
    expect(find.byType(CourseUnitScreen), findsOneWidget);
  });

  testWidgets('shows how many of the 4 parts are done for an in-progress unit', (t) async {
    Api.client = client(progress: [
      {'unit_id': 'pawn', 'lesson_done': true, 'quiz_passed': false, 'puzzles_done': false, 'bot_beaten': false, 'completed_at': null},
    ]);
    await t.pumpWidget(const MaterialApp(home: CoursePathScreen()));
    await t.pumpAndSettle();
    expect(find.text('1 of 4 parts done'), findsOneWidget);
  });
}
