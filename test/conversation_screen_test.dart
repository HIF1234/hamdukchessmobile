import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/social/conversation_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

({http.Client client, List<http.Request> calls}) mockApi(Map<String, Object?> responses) {
  final calls = <http.Request>[];
  final client = MockClient((request) async {
    calls.add(request);
    final path = request.url.path.replaceFirst('/api/app/v1', '');
    final body = responses[path];
    if (body == null) return http.Response(jsonEncode({'error': 'not_found', 'message': 'no mock for $path'}), 404);
    return http.Response(jsonEncode(body), 200);
  });
  return (client: client, calls: calls);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://example.supabase.co', publishableKey: 'anon-key');
  });
  tearDown(() => Api.client = http.Client());

  Future<({http.Client client, List<http.Request> calls})> openConversation(
    WidgetTester t,
    Map<String, Object?> responses,
  ) async {
    final m = mockApi(responses);
    Api.client = m.client;
    await t.pumpWidget(const MaterialApp(home: ConversationScreen(username: 'ade')));
    await t.pumpAndSettle();
    return m;
  }

  testWidgets('friends who are both adults get the free-text box', (t) async {
    await openConversation(t, {
      '/social/messages/ade': {
        'other': {'id': 'u1', 'username': 'ade'},
        'messages': [],
        'canFreeText': true,
        'quickChatPhrases': ['Good game!'],
      },
    });
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Good game!'), findsNothing);
  });

  testWidgets('a stranger or a minor only gets quick chat phrases, not free text', (t) async {
    await openConversation(t, {
      '/social/messages/ade': {
        'other': {'id': 'u1', 'username': 'ade'},
        'messages': [],
        'canFreeText': false,
        'quickChatPhrases': ['Good game!', 'Thanks!'],
      },
    });
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Good game!'), findsOneWidget);
    expect(find.text('Thanks!'), findsOneWidget);
  });

  testWidgets('tapping a quick chat phrase sends it as the message', (t) async {
    final m = await openConversation(t, {
      '/social/messages/ade': {
        'other': {'id': 'u1', 'username': 'ade'},
        'messages': [],
        'canFreeText': false,
        'quickChatPhrases': ['Good game!'],
      },
      '/social/messages/send': {'message': {}},
    });
    await t.tap(find.text('Good game!'));
    await t.pumpAndSettle();
    final sendCall = m.calls.firstWhere((r) => r.url.path.endsWith('/social/messages/send'));
    expect(jsonDecode(sendCall.body) as Map, {'recipientId': 'u1', 'content': 'Good game!'});
  });
}
