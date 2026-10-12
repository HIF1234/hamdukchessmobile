import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/coaching/coaches_screen.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _coaches = [
  {
    'id': 'c1',
    'display_name': 'Tunde Adebayo',
    'fide_title': 'FM',
    'fide_elo': 2250,
    'hourly_rate_kobo': 500000,
    'avg_rating': 4.8,
    'specialties': ['Openings', 'Endgames', 'Tactics', 'Strategy'],
  },
];

void main() {
  tearDown(() => Api.client = http.Client());

  Future<void> open(WidgetTester t, {int status = 200, Object? body}) async {
    final client = MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/coaches') return http.Response(jsonEncode(body ?? _coaches), status);
      return http.Response('{}', 404);
    });
    Api.client = client;
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: CoachesScreen()));
    await t.pumpAndSettle();
  }

  testWidgets('lists coaches with title, rating, rate and up to 3 specialties', (t) async {
    await open(t);
    expect(find.text('FM Tunde Adebayo'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('FIDE 2250'), findsOneWidget);
    expect(find.text('₦5000/hr'), findsOneWidget);
    expect(find.text('Openings'), findsOneWidget);
    expect(find.text('Endgames'), findsOneWidget);
    expect(find.text('Tactics'), findsOneWidget);
    expect(find.text('Strategy'), findsNothing); // only the first 3 specialties show
  });

  testWidgets('shows an empty state when no coaches are active', (t) async {
    await open(t, body: <Object?>[]);
    expect(find.text('No coaches are active right now.'), findsOneWidget);
  });

  testWidgets('shows an error message when the request fails', (t) async {
    await open(t, status: 500, body: {'error': 'rejected', 'message': 'Could not load coaches.'});
    expect(find.text('Could not load coaches.'), findsOneWidget);
  });
}
