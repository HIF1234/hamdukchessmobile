import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'settings.dart';

/// An error from the API: `code` is one of unauthorized, mfa_required, upgrade_required,
/// not_found, limited, bad_request, rejected, or `network` when the request never landed.
class ApiError implements Exception {
  ApiError(this.code, this.message, [this.status]);
  final String code;
  final String message;
  final int? status;

  bool get isNetwork => code == 'network';

  @override
  String toString() => message;
}

/// Calls /api/app/v1 with the signed-in player's Supabase token.
class Api {
  Api._();
  static final instance = Api._();

  /// Swappable for tests (e.g. `package:http/testing.dart`'s MockClient) so screens that call
  /// Api.instance can be widget-tested without hitting the network. Production code never
  /// touches this.
  static http.Client client = http.Client();

  Future<dynamic> get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> delete(String path, [Object? body]) => _send('DELETE', path, body: body);

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    // Defensive: if Supabase isn't initialized (e.g. a widget test rendering a screen in
    // isolation), send unauthenticated rather than crash before the request is even made.
    String? token;
    try {
      token = Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      token = null;
    }
    final uri = Uri.parse('$apiBase$path').replace(queryParameters: query);
    final req = http.Request(method, uri)
      ..headers.addAll({
        if (token != null) 'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 15)));
    } catch (e) {
      throw ApiError('network', 'No connection. Check your data or Wi-Fi.');
    }
    DataMeter.add(req.contentLength + res.bodyBytes.length);
    final json = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final map = json is Map ? json : const {};
      throw ApiError(map['error'] as String? ?? 'error', map['message'] as String? ?? 'Something went wrong', res.statusCode);
    }
    return json;
  }
}
