import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/opening_trainer_screen.dart';
import 'package:hamduk_chess/learn/openings_list_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  List<Map<String, dynamic>> openings() => [
        {
          'eco': 'C60',
          'name': 'Ruy Lopez, Main Line',
          'color': 'white',
          'category': 'e4',
          'description': 'desc',
          'ideas': <String>[],
          'moves': ['e2e4', 'e7e5'],
        },
        {
          'eco': 'B90',
          'name': 'Sicilian Najdorf',
          'color': 'black',
          'category': 'sicilian',
          'description': 'desc',
          'ideas': <String>[],
          'moves': ['e2e4', 'c7c5'],
        },
      ];

  MockClient client({
    String tier = 'free',
    List<Map<String, dynamic>> progress = const [],
    List<Map<String, dynamic>> repertoire = const [],
    int postRepertoireStatus = 200,
  }) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/openings') return http.Response(jsonEncode({'openings': openings()}), 200);
      if (path == '/me') return http.Response(jsonEncode({'account': {'tier': tier}}), 200);
      if (path == '/openings/progress' && request.method == 'GET') return http.Response(jsonEncode(progress), 200);
      if (path == '/openings/repertoire' && request.method == 'GET') return http.Response(jsonEncode(repertoire), 200);
      if (path == '/openings/repertoire' && request.method == 'POST') {
        return http.Response(jsonEncode({'id': 'new-rep-id'}), postRepertoireStatus);
      }
      if (path.startsWith('/openings/repertoire/') && request.method == 'DELETE') return http.Response('{}', 200);
      return http.Response('{}', 404);
    });
  }

  testWidgets('lists openings grouped by category with progress', (t) async {
    Api.client = client(progress: [
      {'eco': 'C60', 'attempts': 4, 'correct': 3, 'mastered_depth': 2, 'last_practiced_at': null},
    ]);
    await t.pumpWidget(const MaterialApp(home: OpeningsListScreen()));
    await t.pumpAndSettle();
    expect(find.text('1. e4 Openings'), findsOneWidget);
    expect(find.text('Sicilian Systems'), findsOneWidget);
    expect(find.text('Ruy Lopez, Main Line'), findsOneWidget);
    expect(find.textContaining('mastered to ply 2'), findsOneWidget);
  });

  testWidgets('tapping an opening opens the trainer', (t) async {
    Api.client = client();
    await t.pumpWidget(const MaterialApp(home: OpeningsListScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Ruy Lopez, Main Line'));
    await t.pumpAndSettle();
    expect(find.byType(OpeningTrainerScreen), findsOneWidget);
  });

  testWidgets('a free player tapping the bookmark sees the Gold upsell, not an add', (t) async {
    Api.client = client(tier: 'free');
    await t.pumpWidget(const MaterialApp(home: OpeningsListScreen()));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.bookmark_border_rounded).first);
    await t.pumpAndSettle();
    expect(find.textContaining('Gold'), findsWidgets);
  });

  testWidgets('a Gold player can add an opening to their repertoire', (t) async {
    Api.client = client(tier: 'gold');
    await t.pumpWidget(const MaterialApp(home: OpeningsListScreen()));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.bookmark_border_rounded).first);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });

  testWidgets('a Gold player can remove an opening already in their repertoire', (t) async {
    Api.client = client(
      tier: 'gold',
      repertoire: [
        {'id': 'rep-1', 'eco': 'C60', 'color': 'white', 'notes': null, 'created_at': ''},
      ],
    );
    await t.pumpWidget(const MaterialApp(home: OpeningsListScreen()));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.bookmark_rounded));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
  });
}
