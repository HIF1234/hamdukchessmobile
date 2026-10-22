import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/endgame_trainer_screen.dart';
import 'package:hamduk_chess/learn/endgames_list_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  List<Map<String, dynamic>> endgames() => [
        {
          'id': 'kqk-1',
          'title': 'King & Queen vs King',
          'description': 'desc',
          'category': 'basic-mates',
          'difficulty': 1,
          'fen': '4k3/8/8/8/8/8/4K3/4Q3 w - - 0 1',
          'userColor': 'white',
          'goal': {'kind': 'mate', 'maxMoves': 10},
        },
        {
          'id': 'lucena-1',
          'title': 'The Lucena Position',
          'description': 'desc',
          'category': 'rook-endings',
          'difficulty': 4,
          'fen': '1K6/1P1k4/8/8/8/8/r7/2R5 w - - 0 1',
          'userColor': 'white',
          'goal': {'kind': 'promote', 'maxMoves': 8},
        },
      ];

  List<Map<String, dynamic>> categories() => [
        {'id': 'basic-mates', 'label': 'Basic Mates', 'description': ''},
        {'id': 'rook-endings', 'label': 'Rook Endings', 'description': ''},
      ];

  MockClient client({List<Map<String, dynamic>> progress = const []}) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/endgames') return http.Response(jsonEncode({'endgames': endgames(), 'categories': categories()}), 200);
      if (path == '/endgames/progress') return http.Response(jsonEncode(progress), 200);
      return http.Response('{}', 404);
    });
  }

  testWidgets('lists endgames grouped by category with progress', (t) async {
    Api.client = client(progress: [
      {'endgame_id': 'kqk-1', 'attempts': 2, 'completed': true, 'best_move_count': 6, 'last_practiced_at': null},
    ]);
    await t.pumpWidget(const MaterialApp(home: EndgamesListScreen()));
    await t.pumpAndSettle();
    expect(find.text('Basic Mates'), findsOneWidget);
    expect(find.text('Rook Endings'), findsOneWidget);
    expect(find.text('King & Queen vs King'), findsOneWidget);
    expect(find.textContaining('best 6 moves'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('tapping an endgame opens the trainer', (t) async {
    Api.client = client();
    await t.pumpWidget(const MaterialApp(home: EndgamesListScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('King & Queen vs King'));
    await t.pumpAndSettle();
    expect(find.byType(EndgameTrainerScreen), findsOneWidget);
  });
}
