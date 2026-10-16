import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/puzzles/streak_screen.dart';
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

Future<void> openStreak(WidgetTester t, Map<String, Object?> responses) async {
  Api.client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/app/v1', '');
    final body = responses[path];
    if (body == null) return http.Response(jsonEncode({'error': 'not_found'}), 404);
    return http.Response(jsonEncode(body), 200);
  });
  t.view.physicalSize = const Size(800, 2200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(const MaterialApp(home: StreakScreen()));
  await t.pumpAndSettle();
}

Future<void> tapSquare(WidgetTester t, String sq) async {
  final board = find.byType(ChessBoardView);
  final origin = t.getTopLeft(board);
  final sqSize = t.getSize(board).width / 8;
  final file = sq.codeUnitAt(0) - 97;
  final rank = int.parse(sq[1]);
  final at = Offset(file * sqSize + sqSize / 2, (8 - rank) * sqSize + sqSize / 2);
  await t.tapAt(origin + at);
  await t.pump();
}

void main() {
  tearDown(() => Api.client = http.Client());

  testWidgets('idle screen shows the personal best and a Start button', (t) async {
    await openStreak(t, {
      '/puzzles/streak/stats': {'best': 7},
    });
    expect(find.text('Your best streak: 7'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('solving the last offered puzzle ends the run and submits the streak', (t) async {
    await openStreak(t, {
      '/puzzles/streak/stats': {'best': 0},
      '/puzzles/streak/stream': {'puzzles': [mateIn1]},
      '/puzzles/streak/submit': {'personalBest': 1},
    });
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();

    await tapSquare(t, 'd1');
    await tapSquare(t, 'd8');
    await t.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Streak: 1'), findsOneWidget);
    expect(find.text('New personal best!'), findsOneWidget);
  });

  testWidgets('allows two misses before ending the run on the third (chess.com Survival rules)', (t) async {
    final puzzles = List.generate(
      4,
      (i) => {
        'id': '0000000-000$i',
        'fen': mateIn1['fen'],
        'solution': mateIn1['solution'],
        'themes': mateIn1['themes'],
        'rating': 900,
      },
    );
    await openStreak(t, {
      '/puzzles/streak/stats': {'best': 0},
      '/puzzles/streak/stream': {'puzzles': puzzles},
      '/puzzles/streak/submit': {'personalBest': 1},
    });
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();

    // Miss #1: a legal but wrong move.
    await tapSquare(t, 'f2');
    await tapSquare(t, 'f3');
    await t.pump();
    expect(find.text('Missed it. 2 misses left.'), findsOneWidget);
    await t.pumpAndSettle(const Duration(milliseconds: 500));

    // Miss #2.
    await tapSquare(t, 'f2');
    await tapSquare(t, 'f3');
    await t.pump();
    expect(find.text('Missed it. 1 miss left.'), findsOneWidget);
    await t.pumpAndSettle(const Duration(milliseconds: 500));

    // A solve in between still counts toward the streak.
    await tapSquare(t, 'd1');
    await tapSquare(t, 'd8');
    await t.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Streak', skipOffstage: false), findsWidgets);

    // Miss #3 ends the run.
    await tapSquare(t, 'f2');
    await tapSquare(t, 'f3');
    await t.pump();
    expect(find.text('Missed it. Streak over.'), findsOneWidget);
    await t.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Streak: 1'), findsOneWidget);
  });

  testWidgets('a failed stream fetch shows the error inline instead of crashing', (t) async {
    await openStreak(t, {'/puzzles/streak/stats': {'best': 0}});
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
