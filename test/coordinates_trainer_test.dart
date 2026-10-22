import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/learn/coordinates_trainer_screen.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  // Tall enough that the whole board is on-screen without scrolling -- taps need to actually
  // hit the square widgets, and the default 600dp test surface doesn't fit text + an 8x8 board.
  void useTallSurface(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
  }

  MockClient client({int best = 7, int? postedBest}) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/coordinates/best' && request.method == 'GET') {
        return http.Response(jsonEncode({'best': best}), 200);
      }
      if (path == '/coordinates/best' && request.method == 'POST') {
        return http.Response(jsonEncode({'best': postedBest ?? best}), 200);
      }
      return http.Response('{}', 404);
    });
  }

  String targetSquareFrom(WidgetTester t) {
    final text = (t.widget(find.textContaining('Tap ')) as Text).data!;
    return text.replaceFirst('Tap ', '').toLowerCase();
  }

  testWidgets('shows the synced best score before starting', (t) async {
    Api.client = client(best: 12);
    await t.pumpWidget(const MaterialApp(home: CoordinatesTrainerScreen()));
    await t.pumpAndSettle();
    expect(find.text('Best: 12'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('starting a round shows the countdown and a target square', (t) async {
    Api.client = client();
    await t.pumpWidget(const MaterialApp(home: CoordinatesTrainerScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Start'));
    await t.pump();
    expect(find.text('Score: 0'), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    expect(find.textContaining('Tap '), findsOneWidget);
    // Let the round's own timer run out so no Timer is left pending when the test ends.
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpAndSettle();
  });

  testWidgets('tapping the right square increases the score and picks a new target', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(const MaterialApp(home: CoordinatesTrainerScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Start'));
    await t.pump();
    final square = targetSquareFrom(t);
    await t.tap(find.byKey(Key('square_$square')));
    await t.pump();
    expect(find.text('Score: 1'), findsOneWidget);
    // Let the round's own timer run out so no Timer is left pending when the test ends.
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpAndSettle();
  });

  testWidgets('tapping the wrong square does not change the score', (t) async {
    useTallSurface(t);
    Api.client = client();
    await t.pumpWidget(const MaterialApp(home: CoordinatesTrainerScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Start'));
    await t.pump();
    final square = targetSquareFrom(t);
    final wrong = square == 'a1' ? 'h8' : 'a1';
    await t.tap(find.byKey(Key('square_$wrong')));
    await t.pump();
    expect(find.text('Score: 0'), findsOneWidget);
    // Let the wrong-tap flash and the round's own timer run out so no Timer is left pending
    // when the test ends.
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpAndSettle();
  });

  testWidgets('the round ends after 30 seconds and reports the score as a new best', (t) async {
    useTallSurface(t);
    Api.client = client(best: 0, postedBest: 1);
    await t.pumpWidget(const MaterialApp(home: CoordinatesTrainerScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Start'));
    await t.pump();
    final square = targetSquareFrom(t);
    await t.tap(find.byKey(Key('square_$square')));
    await t.pump();
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpAndSettle();
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Last round: 1'), findsOneWidget);
    expect(find.text('Best: 1'), findsOneWidget);
  });
}
