import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/puzzles/from_games_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Back-rank blunder: Rd1-d8 would have been mate.
final _blunder = {
  'id': '00000000-0000-0000-0000-00000000000a',
  'fen': '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',
  'best_move': 'd1d8',
  'created_at': DateTime.now().toUtc().toIso8601String(),
};

Future<void> openFromGames(WidgetTester t, Map<String, Object?> responses) async {
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
  await t.pumpWidget(const MaterialApp(home: FromGamesScreen()));
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

  testWidgets('shows an empty state when there is nothing yet', (t) async {
    await openFromGames(t, {'/puzzles/from-games': {'puzzles': []}});
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('lists a saved blunder, from today', (t) async {
    await openFromGames(t, {'/puzzles/from-games': {'puzzles': [_blunder]}});
    expect(find.text('Blunder to fix'), findsOneWidget);
    expect(find.text('From a game today'), findsOneWidget);
  });

  testWidgets('solving the retry removes it from the list', (t) async {
    await openFromGames(t, {
      '/puzzles/from-games': {'puzzles': [_blunder]},
      '/puzzles/from-games/${_blunder['id']}/attempt': {'ok': true},
    });
    await t.tap(find.text('Blunder to fix'));
    await t.pumpAndSettle();

    await tapSquare(t, 'd1');
    await tapSquare(t, 'd8');
    await t.pumpAndSettle();
    expect(find.text('Solved!'), findsOneWidget);

    await t.tap(find.text('Done'));
    await t.pumpAndSettle();

    expect(find.text('Nothing here yet'), findsOneWidget);
  });
}
