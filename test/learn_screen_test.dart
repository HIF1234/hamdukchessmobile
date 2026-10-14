import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/learn_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  tearDown(() => Api.client = http.Client());

  Future<void> open(WidgetTester t, {String tier = 'free'}) async {
    final client = MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      switch (path) {
        case '/tutorials':
          return http.Response(
            jsonEncode([
              {
                'id': 't1',
                'title': 'Board Basics',
                'level': 'starter',
                'topic': 'basics',
                'estimatedMinutes': 4,
                'steps': [
                  {'kind': 'observe', 'fen': _fen, 'title': 'Step 1', 'body': 'Look at the board.'},
                ],
              },
            ]),
            200,
          );
        case '/videos':
          return http.Response(
            jsonEncode([
              {
                'id': 'v1',
                'title': 'Free Lesson',
                'category': 'Openings',
                'difficulty': 'beginner',
                'source': 'youtube',
                'external_id': 'abc123',
                'duration_sec': 300,
                'instructor': 'Coach A',
                'is_premium': false,
                'sort_order': 0,
              },
              {
                'id': 'v2',
                'title': 'Gold Lesson',
                'category': 'Endgames',
                'difficulty': 'advanced',
                'source': 'youtube',
                'external_id': 'xyz789',
                'duration_sec': 600,
                'instructor': 'Coach B',
                'is_premium': true,
                'sort_order': 0,
              },
            ]),
            200,
          );
        case '/me':
          return http.Response(
            jsonEncode({
              'account': {'tier': tier},
            }),
            200,
          );
        default:
          return http.Response('{}', 404);
      }
    });
    Api.client = client;
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: LearnScreen()));
    await t.pumpAndSettle();
  }

  testWidgets('lists tutorials and video lessons grouped by category', (t) async {
    await open(t);
    expect(find.text('Board Basics'), findsOneWidget);
    expect(find.text('Free Lesson'), findsOneWidget);
    expect(find.text('Gold Lesson'), findsOneWidget);
    // Premium lessons get a crown icon instead of a plain chevron.
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });

  testWidgets('a free lesson plays without a paywall', (t) async {
    await open(t, tier: 'free');
    await t.tap(find.text('Free Lesson'));
    // webview_flutter has no platform channel in a plain widget test, so its controller never
    // settles (pumpAndSettle would hang) -- a bounded pump is enough to confirm no paywall shows.
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('This lesson is on the Gold plan.'), findsNothing);
  });

  testWidgets('a premium lesson is paywalled for a free-tier player', (t) async {
    await open(t, tier: 'free');
    await t.tap(find.text('Gold Lesson'));
    await t.pumpAndSettle();
    expect(find.text('This lesson is on the Gold plan.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Upgrade'), findsOneWidget);
  });

  testWidgets('a premium lesson plays for a Gold player', (t) async {
    await open(t, tier: 'gold');
    await t.tap(find.text('Gold Lesson'));
    await t.pump(const Duration(milliseconds: 200)); // see note above on webview + pumpAndSettle
    expect(find.text('This lesson is on the Gold plan.'), findsNothing);
  });

  testWidgets('tapping a tutorial opens the step player', (t) async {
    await open(t);
    await t.tap(find.text('Board Basics'));
    await t.pumpAndSettle();
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Look at the board.'), findsOneWidget);
  });
}
