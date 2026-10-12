import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/core/report_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  Future<void> open(WidgetTester t, {required http.Client client}) async {
    Api.client = client;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showReportDialog(context, targetType: 'user', targetId: 'target-1'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  MockClient reasonsOnlyClient({int reportStatus = 200, Object? reportBody}) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/report/reasons') {
        return http.Response(
          jsonEncode([
            {'id': 'cheating', 'label': 'Cheating / engine use'},
            {'id': 'abuse', 'label': 'Abuse or harassment'},
          ]),
          200,
        );
      }
      if (path == '/report') {
        return http.Response(jsonEncode(reportBody ?? {'ok': true}), reportStatus);
      }
      return http.Response('{}', 404);
    });
  }

  testWidgets('shows the reasons fetched from the server', (t) async {
    await open(t, client: reasonsOnlyClient());
    expect(find.text('Cheating / engine use'), findsOneWidget);
    expect(find.text('Abuse or harassment'), findsOneWidget);
  });

  testWidgets('requires a reason before submitting', (t) async {
    await open(t, client: reasonsOnlyClient());
    await t.tap(find.widgetWithText(FilledButton, 'Submit report'));
    await t.pump();
    expect(find.text('Pick a reason.'), findsOneWidget);
  });

  testWidgets('submits the chosen reason and optional details, then closes', (t) async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/report/reasons') {
        return http.Response(jsonEncode([{'id': 'spam', 'label': 'Spam or scams'}]), 200);
      }
      if (path == '/report') return http.Response(jsonEncode({'ok': true}), 200);
      return http.Response('{}', 404);
    });
    await open(t, client: client);
    await t.tap(find.text('Spam or scams'));
    await t.enterText(find.byType(TextField), 'Kept DMing me ads.');
    await t.tap(find.widgetWithText(FilledButton, 'Submit report'));
    await t.pumpAndSettle();

    final reportCall = calls.firstWhere((r) => r.url.path.endsWith('/report'));
    final sent = jsonDecode(reportCall.body) as Map;
    expect(sent['targetType'], 'user');
    expect(sent['targetId'], 'target-1');
    expect(sent['reason'], 'spam');
    expect(sent['details'], 'Kept DMing me ads.');
    // The dialog closed (its title is gone) once the report was filed.
    expect(find.text('Report'), findsNothing);
  });

  testWidgets('shows the server error (e.g. daily limit) instead of closing', (t) async {
    await open(
      t,
      client: reasonsOnlyClient(reportStatus: 429, reportBody: {'error': 'limited', 'message': "You've sent 5 reports today."}),
    );
    await t.tap(find.text('Cheating / engine use'));
    await t.tap(find.widgetWithText(FilledButton, 'Submit report'));
    await t.pumpAndSettle();
    expect(find.text("You've sent 5 reports today."), findsOneWidget);
  });
}
