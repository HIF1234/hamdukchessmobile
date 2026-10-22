import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/learn/certificates_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => Api.client = http.Client());

  List<Map<String, dynamic>> certificates() => [
        {
          'id': 'cert-1',
          'unit_id': 'pawn',
          'piece_name': 'Pawn',
          'unit_title': 'The Board & Setup',
          'player_name': 'tester',
          'issued_at': '2026-01-01T00:00:00Z',
        },
      ];

  MockClient client({List<Map<String, dynamic>> certs = const []}) {
    return MockClient((request) async {
      final path = request.url.path.replaceFirst('/api/app/v1', '');
      if (path == '/certificates') return http.Response(jsonEncode({'certificates': certs}), 200);
      return http.Response('{}', 404);
    });
  }

  testWidgets('shows an empty state when no certificates are earned yet', (t) async {
    Api.client = client();
    await t.pumpWidget(const MaterialApp(home: CertificatesScreen()));
    await t.pumpAndSettle();
    expect(find.text('No certificates yet'), findsOneWidget);
  });

  testWidgets('lists earned certificates', (t) async {
    Api.client = client(certs: certificates());
    await t.pumpWidget(const MaterialApp(home: CertificatesScreen()));
    await t.pumpAndSettle();
    expect(find.text('Pawn level'), findsOneWidget);
    expect(find.text('The Board & Setup'), findsOneWidget);
  });

  testWidgets('shows an error message if the certificates fail to load', (t) async {
    Api.client = MockClient((request) async => http.Response(jsonEncode({'error': 'error', 'message': 'Offline'}), 500));
    await t.pumpWidget(const MaterialApp(home: CertificatesScreen()));
    await t.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
  });
}
