import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/board_vision_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  void useTallSurface(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
  }

  MockClient client(List<Map<String, dynamic>> puzzles) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/board-vision/puzzles') return http.Response(jsonEncode({'puzzles': puzzles}), 200);
      return http.Response('{}', 404);
    });
  }

  // White queen on e6 is hanging (black's solution move captures it).
  const hangingFen = '4k3/8/4Q3/8/8/8/8/4K3 b - - 0 1';
  const hangingSolution = ['e8e6'];

  // A position with no relevant tag and no legal move giving check, so it must be skipped.
  const quietFen = '4k3/8/8/8/8/8/8/4K3 w - - 0 1';

  // White rook on h1 can play Rh8+ (black king on e8, open h-file-ish... use a real checking
  // position: white queen can deliver check along the e-file).
  const checkFen = '4k3/8/8/8/8/8/8/4Q1K1 w - - 0 1';

  testWidgets('a hangingPiece-themed puzzle asks to tap the hanging piece', (t) async {
    Api.client = client([
      {'fen': hangingFen, 'solution': hangingSolution, 'themes': ['hangingPiece']},
    ]);
    await t.pumpWidget(const MaterialApp(home: BoardVisionScreen()));
    await t.pumpAndSettle();
    expect(find.text('Tap the hanging piece.'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('a quiet position with no theme and no check is skipped entirely', (t) async {
    Api.client = client([
      {'fen': quietFen, 'solution': [], 'themes': []},
    ]);
    await t.pumpWidget(const MaterialApp(home: BoardVisionScreen()));
    await t.pumpAndSettle();
    expect(find.text('No drills available right now.'), findsOneWidget);
  });

  testWidgets('an unthemed position with a legal check asks to spot the checking move', (t) async {
    Api.client = client([
      {'fen': checkFen, 'solution': [], 'themes': []},
    ]);
    await t.pumpWidget(const MaterialApp(home: BoardVisionScreen()));
    await t.pumpAndSettle();
    expect(find.text('Tap a square a piece could move to for check.'), findsOneWidget);
  });

  testWidgets('tapping the hanging piece counts as correct and advances', (t) async {
    useTallSurface(t);
    Api.client = client([
      {'fen': hangingFen, 'solution': hangingSolution, 'themes': ['hangingPiece']},
      {'fen': quietFen, 'solution': [], 'themes': []}, // skipped, so the batch is really 1 round
    ]);
    await t.pumpWidget(const MaterialApp(home: BoardVisionScreen()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('square_e6')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(find.text('1 / 1 correct'), findsOneWidget);
  });

  testWidgets('tapping the wrong square counts as incorrect', (t) async {
    useTallSurface(t);
    Api.client = client([
      {'fen': hangingFen, 'solution': hangingSolution, 'themes': ['hangingPiece']},
    ]);
    await t.pumpWidget(const MaterialApp(home: BoardVisionScreen()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('square_a1')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(find.text('0 / 1 correct'), findsOneWidget);
  });

  testWidgets('running out of time counts as incorrect', (t) async {
    Api.client = client([
      {'fen': hangingFen, 'solution': hangingSolution, 'themes': ['hangingPiece']},
    ]);
    await t.pumpWidget(const MaterialApp(home: BoardVisionScreen()));
    await t.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(find.text('0 / 1 correct'), findsOneWidget);
  });
}
