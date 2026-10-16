import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/puzzles/theme_stats_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> openThemeStats(WidgetTester t, Map<String, Object?> responses) async {
  Api.client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/app/v1', '');
    final body = responses[path];
    if (body == null) return http.Response(jsonEncode({'error': 'not_found'}), 404);
    return http.Response(jsonEncode(body), 200);
  });
  await t.pumpWidget(const MaterialApp(home: ThemeStatsScreen()));
  await t.pumpAndSettle();
}

void main() {
  tearDown(() => Api.client = http.Client());

  testWidgets('shows the weakest theme first, then the full list', (t) async {
    await openThemeStats(t, {
      '/puzzles/theme-stats': {
        'themes': [
          {'theme': 'backRankMate', 'attempted': 10, 'solved': 4, 'accuracy': 40},
          {'theme': 'fork', 'attempted': 18, 'solved': 13, 'accuracy': 72},
        ],
      },
    });

    expect(find.text('WEAKEST THEME'), findsOneWidget);
    expect(find.text('Back rank'), findsWidgets); // once in the callout, once in the list
    expect(find.text('40% accuracy over 10 puzzles'), findsOneWidget);
    expect(find.text('Forks'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
  });

  testWidgets('shows an empty state before any puzzles are solved', (t) async {
    await openThemeStats(t, {'/puzzles/theme-stats': {'themes': []}});
    expect(find.text('No puzzles solved yet'), findsOneWidget);
  });
}
