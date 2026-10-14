import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/tournaments/tournaments_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _rows = [
  {
    'id': 't-live',
    'name': 'Lagos Open',
    'status': 'live',
    'type': 'swiss',
    'time_control': '5+0',
    'variant': 'standard',
    'rated': true,
    'entry_fee_kobo': 0,
    'min_tier': 'free',
    'max_players': 32,
    'starts_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
  },
  {
    'id': 't-scheduled',
    'name': 'Gold Arena',
    'status': 'scheduled',
    'type': 'arena',
    'time_control': '3+2',
    'variant': 'standard',
    'rated': true,
    'entry_fee_kobo': 50000,
    'min_tier': 'gold',
    'max_players': 64,
    'starts_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
  },
];

void main() {
  tearDown(() => Api.client = http.Client());

  Future<void> open(WidgetTester t, {Object? responseOverride}) async {
    final client = MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/tournaments') {
        return http.Response(
          jsonEncode(responseOverride ?? {'tournaments': _rows, 'counts': {'t-live': 12, 't-scheduled': 3}}),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    Api.client = client;
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TournamentsScreen())));
    await t.pumpAndSettle();
  }

  testWidgets('groups tournaments into Live/Scheduled/Completed sections', (t) async {
    await open(t);
    // Lagos Open is live, so it also appears in the featured HeroCard above the sections.
    expect(find.text('Lagos Open'), findsNWidgets(2));
    expect(find.text('Gold Arena'), findsOneWidget);
    // SectionLabel renders its text upper-cased.
    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('SCHEDULED'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsOneWidget); // Completed is empty
  });

  testWidgets('shows entrant counts and the gold-tier badge', (t) async {
    await open(t);
    expect(find.text('12/32'), findsOneWidget);
    expect(find.textContaining('gold+'), findsOneWidget);
    expect(find.textContaining('₦500'), findsOneWidget); // 50000 kobo -> ₦500
  });

  testWidgets('shows an error message when the request fails', (t) async {
    final client = MockClient((request) async => http.Response(jsonEncode({'error': 'rejected', 'message': 'Server unavailable'}), 500));
    Api.client = client;
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TournamentsScreen())));
    await t.pumpAndSettle();
    expect(find.text('Server unavailable'), findsOneWidget);
  });
}
