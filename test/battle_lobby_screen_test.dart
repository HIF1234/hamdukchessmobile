import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/puzzles/battle_lobby_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> openLobby(WidgetTester t, Map<String, Object?> responses) async {
  Api.client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/app/v1', '');
    final body = responses[path];
    if (body == null) return http.Response(jsonEncode({'error': 'not_found'}), 404);
    return http.Response(jsonEncode(body), 200);
  });
  await t.pumpWidget(const MaterialApp(home: BattleLobbyScreen()));
  await t.pumpAndSettle();
}

void main() {
  tearDown(() => Api.client = http.Client());

  testWidgets('shows the two entry actions and recent battles', (t) async {
    await openLobby(t, {
      '/puzzles/battle/mine': {
        'battles': [
          {'id': '1', 'opponent': 'Bola', 'mine': 5, 'theirs': 3, 'result': 'won'},
        ],
      },
    });
    expect(find.text('Find an opponent'), findsOneWidget);
    expect(find.text('Challenge a friend'), findsOneWidget);
    expect(find.text('vs Bola'), findsOneWidget);
    expect(find.text('WON'), findsOneWidget);
  });

  testWidgets('a failed find shows the error inline instead of crashing', (t) async {
    await openLobby(t, {'/puzzles/battle/mine': {'battles': []}});
    await t.tap(find.text('Find an opponent'));
    await t.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
