import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/social/social_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds a MockClient that serves canned JSON per path, and records every request made so
/// tests can assert the app called the right endpoint with the right body.
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
  tearDown(() => Api.client = http.Client());

  Future<void> openSocial(WidgetTester t, Map<String, Object?> responses) async {
    final m = mockApi(responses);
    Api.client = m.client;
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SocialScreen())));
    await t.pumpAndSettle();
  }

  testWidgets('friends tab shows incoming requests and accepted friends', (t) async {
    await openSocial(t, {
      '/social/friends': {
        'accepted': [
          {'username': 'ade', 'rating': 1500},
        ],
        'incoming': [
          {'id': 'req-1', 'username': 'bola', 'rating': 1200},
        ],
        'outgoing': [],
      },
      '/social/feed': {'items': []},
      '/social/messages': {'conversations': []},
    });

    expect(find.text('ade'), findsOneWidget);
    expect(find.text('bola'), findsOneWidget);
    expect(find.text('Rating 1500'), findsOneWidget);
  });

  testWidgets('accepting a friend request calls respond with accept:true and reloads', (t) async {
    var accepted = false;
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/social/friends/respond') {
        accepted = true;
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      if (path == '/social/friends') {
        return http.Response(
          jsonEncode({
            'accepted': accepted ? [{'username': 'bola', 'rating': 1200}] : [],
            'incoming': accepted ? [] : [{'id': 'req-1', 'username': 'bola', 'rating': 1200}],
            'outgoing': [],
          }),
          200,
        );
      }
      if (path == '/social/feed') return http.Response(jsonEncode({'items': []}), 200);
      if (path == '/social/messages') return http.Response(jsonEncode({'conversations': []}), 200);
      return http.Response('{}', 404);
    });
    Api.client = client;
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SocialScreen())));
    await t.pumpAndSettle();

    expect(find.text('bola'), findsOneWidget);
    await t.tap(find.byIcon(Icons.check_rounded));
    await t.pumpAndSettle();

    final respondCall = calls.firstWhere((r) => r.url.path.endsWith('/social/friends/respond'));
    final sentBody = jsonDecode(respondCall.body) as Map;
    expect(sentBody['requestId'], 'req-1');
    expect(sentBody['accept'], true);
  });

  testWidgets('adding a friend by username looks up the profile then sends a request', (t) async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/social/friends') {
        return http.Response(jsonEncode({'accepted': [], 'incoming': [], 'outgoing': []}), 200);
      }
      if (path == '/social/feed') return http.Response(jsonEncode({'items': []}), 200);
      if (path == '/social/messages') return http.Response(jsonEncode({'conversations': []}), 200);
      if (path == '/profile/chidi') {
        return http.Response(jsonEncode({'profile': {'id': 'user-42', 'username': 'chidi'}}), 200);
      }
      if (path == '/social/friends/request') {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      return http.Response('{}', 404);
    });
    Api.client = client;
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SocialScreen())));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextField, 'Add a friend by username'), 'chidi');
    await t.tap(find.byIcon(Icons.person_add));
    await t.pumpAndSettle();

    final requestCall = calls.firstWhere((r) => r.url.path.endsWith('/social/friends/request'));
    final sentBody = jsonDecode(requestCall.body) as Map;
    expect(sentBody['userId'], 'user-42');
    expect(find.text('Friend request sent.'), findsOneWidget);
  });

  testWidgets('feed tab shows activity items grouped by type', (t) async {
    await openSocial(t, {
      '/social/friends': {'accepted': [], 'incoming': [], 'outgoing': []},
      '/social/feed': {
        'items': [
          {'username': 'ngozi', 'type': 'won a game'},
        ],
      },
      '/social/messages': {'conversations': []},
    });
    await t.tap(find.widgetWithText(Tab, 'Feed'));
    await t.pumpAndSettle();
    expect(find.text('ngozi'), findsOneWidget);
    expect(find.text('won a game'), findsOneWidget);
  });

  testWidgets('messages tab shows unread badge', (t) async {
    await openSocial(t, {
      '/social/friends': {'accepted': [], 'incoming': [], 'outgoing': []},
      '/social/feed': {'items': []},
      '/social/messages': {
        'conversations': [
          {'username': 'tunde', 'lastMessage': 'gg!', 'unread': 3},
        ],
      },
    });
    await t.tap(find.widgetWithText(Tab, 'Messages'));
    await t.pumpAndSettle();
    expect(find.text('tunde'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
