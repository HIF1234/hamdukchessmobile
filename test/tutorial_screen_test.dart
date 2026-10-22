import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/chess_board.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/tutorial_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final _tutorial = {
  'id': 't1',
  'title': 'Test Tutorial',
  'steps': [
    {'kind': 'observe', 'fen': _startFen, 'title': 'Step 1', 'body': 'Just read this.'},
    {
      'kind': 'move',
      'fen': _startFen,
      'title': 'Step 2',
      'body': 'Play e4.',
      'answer': 'e2e4',
      'hint': 'e2',
    },
  ],
};

/// Taps the centre of [sq] on the currently rendered board, whatever size it laid out at.
Future<void> tapSquare(WidgetTester t, String sq) async {
  final size = t.getSize(find.byType(ChessBoardView));
  final origin = t.getTopLeft(find.byType(ChessBoardView));
  final squareSize = size.width / 8;
  final file = sq.codeUnitAt(0) - 97;
  final rank = int.parse(sq[1]);
  final offset = Offset(file * squareSize + squareSize / 2, (8 - rank) * squareSize + squareSize / 2);
  await t.tapAt(origin + offset);
  await t.pump();
}

void main() {
  tearDown(() => Api.client = http.Client());

  Future<void> open(WidgetTester t) async {
    // The board (full-width AspectRatio) nearly fills the default 600px test viewport, which
    // pushes the title/body/buttons below it outside ListView's build+cache extent -- they
    // never mount and every finder below the board comes back empty. A taller test surface
    // keeps the whole screen within the sliver's lazy-build window.
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    // Progress sync (GET/POST /tutorials/progress) is best-effort and not under test here.
    Api.client = MockClient((request) async => http.Response('[]', 200));
    await t.pumpWidget(MaterialApp(home: TutorialScreen(tutorial: _tutorial)));
    await t.pumpAndSettle();
  }

  testWidgets('an observe step shows Next without requiring a move', (t) async {
    await open(t);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Just read this.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, 'Next'));
    await t.pump();
    expect(find.text('Step 2'), findsOneWidget);
    // A move step hides Next until solved.
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Finish'), findsNothing);
  });

  testWidgets('a wrong move on a move step is rejected, the right one is accepted', (t) async {
    await open(t);
    await t.tap(find.widgetWithText(FilledButton, 'Next'));
    await t.pump();

    // d2-d4 is legal chess but not the tutorial's expected answer (e2e4) -- rejected.
    await tapSquare(t, 'd2');
    await tapSquare(t, 'd4');
    expect(find.text('Not quite -- try again.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Finish'), findsNothing);

    await t.pump(const Duration(milliseconds: 600)); // the "wrong move" flash clears itself
    await tapSquare(t, 'e2');
    await tapSquare(t, 'e4');
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Finish'), findsOneWidget);
  });

  testWidgets('a hint can be requested on a move step', (t) async {
    await open(t);
    await t.tap(find.widgetWithText(FilledButton, 'Next'));
    await t.pump();
    expect(find.text('Hint'), findsOneWidget);
    await t.tap(find.text('Hint'));
    await t.pump();
    // Tapping Hint reveals a highlighted square on the board rather than removing the
    // button itself -- it stays available (and harmless to tap again) until the step is solved.
    expect(find.text('Hint'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('finishing the last step pops the screen', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Api.client = MockClient((request) async => http.Response('[]', 200));
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutorialScreen(tutorial: _tutorial))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Test Tutorial'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, 'Next')); // step 1 -> step 2
    await t.pump();
    await tapSquare(t, 'e2');
    await tapSquare(t, 'e4'); // solves step 2, the last step
    await t.tap(find.widgetWithText(FilledButton, 'Finish'));
    await t.pumpAndSettle();
    expect(find.text('Test Tutorial'), findsNothing); // back on the "open" screen
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('resumes at the saved step unless it was already completed', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Api.client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode([{'tutorial_id': 't1', 'step_index': 1, 'completed': false}]), 200);
      }
      return http.Response('{}', 200);
    });
    await t.pumpWidget(MaterialApp(home: TutorialScreen(tutorial: _tutorial)));
    await t.pumpAndSettle();
    expect(find.text('Step 2'), findsOneWidget);
    expect(find.text('Step 1'), findsNothing);
  });

  testWidgets('a completed tutorial starts over from step 1', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Api.client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode([{'tutorial_id': 't1', 'step_index': 1, 'completed': true}]), 200);
      }
      return http.Response('{}', 200);
    });
    await t.pumpWidget(MaterialApp(home: TutorialScreen(tutorial: _tutorial)));
    await t.pumpAndSettle();
    expect(find.text('Step 1'), findsOneWidget);
  });

  testWidgets('finishing posts completed progress for the website to see', (t) async {
    await open(t);
    final posted = <Map<String, dynamic>>[];
    Api.client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('[]', 200);
      posted.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{}', 200);
    });
    await t.tap(find.widgetWithText(FilledButton, 'Next'));
    await t.pump();
    await tapSquare(t, 'e2');
    await tapSquare(t, 'e4');
    await t.tap(find.widgetWithText(FilledButton, 'Finish'));
    await t.pump();
    expect(posted.last, {'tutorial_id': 't1', 'step_index': 1, 'completed': true});
  });
}
