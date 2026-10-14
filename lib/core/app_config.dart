import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'storage.dart';

const apiBase = 'https://play.chess.hamduk.com.ng/api/app/v1';

/// Backend details and game data from GET /config. Cached so the app starts offline.
class AppConfig {
  AppConfig(this.raw, {this.isBundledFallback = false});
  final Map<String, dynamic> raw;
  /// True when this came from the config bundled with the app, not the server or a cache of
  /// it -- meaning this is a first launch with no network yet.
  final bool isBundledFallback;

  String get supabaseUrl => raw['supabase']['url'] as String;
  String get supabaseAnonKey => raw['supabase']['anonKey'] as String;
  String get minAppVersion => raw['minAppVersion'] as String? ?? '1.0.0';
  /// Set when a newer version exists but isn't required; shows a small banner, not a block.
  String? get latestAppVersion => raw['latestAppVersion'] as String?;
  bool get maintenanceEnabled => (raw['maintenance'] as Map?)?['enabled'] == true;
  String get maintenanceMessage =>
      (raw['maintenance'] as Map?)?['message'] as String? ?? "We're upgrading. Back soon.";
  /// Remote kill switches (e.g. `paidTournaments`). Missing keys default to enabled.
  bool feature(String key) => (raw['features'] as Map?)?[key] as bool? ?? true;
  /// Null until the platform sets GOOGLE_WEB_CLIENT_ID; Google sign-in hides until then.
  String? get googleWebClientId => raw['googleWebClientId'] as String?;
  List<Map<String, dynamic>> get bots => (raw['bots'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get timeControls =>
      (raw['timeControls'] as List).cast<Map<String, dynamic>>();

  static const _cacheKey = 'config';

  /// Fresh config when online, else the cached copy, else the config bundled with the app so
  /// a first launch with no network still works offline (bots, puzzles and local play).
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
    if (cached is Map<String, dynamic>) return AppConfig(cached);
    try {
      final bundled = jsonDecode(await rootBundle.loadString('assets/config/default_config.json'));
      return AppConfig(bundled as Map<String, dynamic>, isBundledFallback: true);
    } catch (_) {
      return null; // shouldn't happen; the asset ships with the app
    }
  }

  /// True when this install is below the server's required version and must update.
  bool isBelowMinVersion(String currentVersion) => _compareVersions(currentVersion, minAppVersion) < 0;

  /// True when a newer, optional version exists.
  bool hasOptionalUpdate(String currentVersion) {
    final latest = latestAppVersion;
    return latest != null && _compareVersions(currentVersion, latest) < 0;
  }
}

/// Compares dotted version strings (e.g. "1.2.0" vs "1.10.0") numerically, not lexically.
int _compareVersions(String a, String b) {
  final pa = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pb = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}
