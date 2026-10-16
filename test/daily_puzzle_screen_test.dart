import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/puzzles/daily_puzzle_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Back-rank mate in 1: Rd8#.
final mateIn1 = {
  'id': '00000000-0000-0000-0000-000000000001',
  'fen': '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',
  'solution': ['d1d8'],
  'themes': ['mateIn1'],
  'rating': 900,
};

Future<void> tap(WidgetTester t, String sq) async {
  final board = find.byType(ChessBoardView);
  final origin = t.getTopLeft(board);
  final sqSize = t.getSize(board).width / 8;
  final file = sq.codeUnitAt(0) - 97;
  final rank = int.parse(sq[1]);
  final at = Offset(file * sqSize + sqSize / 2, (8 - rank) * sqSize + sqSize / 2);
  await t.tapAt(origin + at);
  await t.pump();
}

Future<void> openDailyPuzzle(WidgetTester t, Map<String, Object?> responses) async {
  final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/app/v1', '');
    final body = responses[path];
    if (body == null) return http.Response(jsonEncode({'error': 'not_found'}), 404);
    return http.Response(jsonEncode(body), 200);
  });
  Api.client = client;
  // The board alone (full screen width, square) is taller than the test's default 600px
  // viewport; without more height, everything below it in the ListView's sliver never gets
  // built at all (not just scrolled out of view).
  t.view.physicalSize = const Size(800, 2200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(const MaterialApp(home: DailyPuzzleScreen()));
  await t.pumpAndSettle();
}

void main() {
  tearDown(() => Api.client = http.Client());

  testWidgets('solving shows the streak and a Share button', (t) async {
    await openDailyPuzzle(t, {
      '/puzzles/daily': mateIn1,
      '/puzzles/00000000-0000-0000-0000-000000000001/attempt': {'rating': 910, 'delta': 10},
      '/me': {'puzzles': {'current_streak': 6}},
    });

    // White's rook on d1 mates on d8.
    await tap(t, 'd1');
    await tap(t, 'd8');
    await t.pumpAndSettle();

    expect(find.text('Solved first try!'), findsOneWidget);
    expect(find.text('6-day streak'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Share'), findsOneWidget);
  });

  testWidgets('a wrong move shows no streak or Share button', (t) async {
    await openDailyPuzzle(t, {
      '/puzzles/daily': mateIn1,
      '/puzzles/00000000-0000-0000-0000-000000000001/attempt': {'rating': 900, 'delta': 0},
    });

    await tap(t, 'd1');
    await tap(t, 'd7'); // legal rook move, not the mate
    await t.pumpAndSettle();

    expect(find.textContaining('Not quite'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Share'), findsNothing);
  });
}
