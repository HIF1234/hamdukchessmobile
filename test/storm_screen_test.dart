import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/puzzles/storm_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> openStorm(WidgetTester t, Map<String, Object?> responses) async {
  Api.client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/app/v1', '');
    final body = responses[path];
    if (body == null) return http.Response(jsonEncode({'error': 'not_found'}), 404);
    return http.Response(jsonEncode(body), 200);
  });
  await t.pumpWidget(const MaterialApp(home: StormScreen()));
  await t.pumpAndSettle();
}

void main() {
  tearDown(() => Api.client = http.Client());

  testWidgets('a free-tier player sees the Plus/Gold paywall, not the game', (t) async {
    await openStorm(t, {
      '/me': {'account': {'tier': 'free'}},
    });
    expect(find.text('Puzzle Storm is Plus / Gold'), findsOneWidget);
    expect(find.text('Start 3-minute storm'), findsNothing);
  });

  testWidgets('a Plus player sees the start screen, their best, and the leaderboard', (t) async {
    await openStorm(t, {
      '/me': {'account': {'tier': 'plus'}},
      '/puzzles/storm/stats': {'best': 23, 'runs': 4, 'recent': []},
      '/puzzles/storm/leaderboard': {
        'entries': [
          {'userId': 'a', 'username': 'Ade', 'score': 30},
          {'userId': 'b', 'username': 'Bola', 'score': 25},
        ],
      },
    });
    expect(find.text('Start 3-minute storm'), findsOneWidget);
    expect(find.text('Your best: 23'), findsOneWidget);
    expect(find.text('Ade'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('an empty leaderboard shows a friendly message, not a crash', (t) async {
    await openStorm(t, {
      '/me': {'account': {'tier': 'gold'}},
      '/puzzles/storm/stats': {'best': 0, 'runs': 0, 'recent': []},
      '/puzzles/storm/leaderboard': {'entries': []},
    });
    expect(find.text('No runs yet. Be the first.'), findsOneWidget);
  });
}
