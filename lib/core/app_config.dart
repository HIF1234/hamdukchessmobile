import 'dart:convert';

import 'package:http/http.dart' as http;

import 'storage.dart';

const apiBase = 'https://play.chess.hamduk.com.ng/api/app/v1';

/// Backend details and game data from GET /config. Cached so the app starts offline.
class AppConfig {
  AppConfig(this.raw);
  final Map<String, dynamic> raw;

  String get supabaseUrl => raw['supabase']['url'] as String;
  String get supabaseAnonKey => raw['supabase']['anonKey'] as String;
  String get minAppVersion => raw['minAppVersion'] as String? ?? '1.0.0';
  /// Null until the platform sets GOOGLE_WEB_CLIENT_ID; Google sign-in hides until then.
  String? get googleWebClientId => raw['googleWebClientId'] as String?;
  List<Map<String, dynamic>> get bots => (raw['bots'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get timeControls =>
      (raw['timeControls'] as List).cast<Map<String, dynamic>>();

  static const _cacheKey = 'config';

  /// Fresh config when online, else the cached copy. Null only on a first run with no network.
  static Future<AppConfig?> load() async {
    final store = await JsonStore.open();
    try {
      final res = await http
          .get(Uri.parse('$apiBase/config'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        await store.write(_cacheKey, json);
        return AppConfig(json);
      }
    } catch (_) {
      // offline or slow network: fall back to the cache
    }
    final cached = await store.read(_cacheKey);
    return cached is Map<String, dynamic> ? AppConfig(cached) : null;
  }
}
