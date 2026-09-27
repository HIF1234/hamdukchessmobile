import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reports and product analytics (Firebase). Players are identified only by their
/// account's random ID, never by name or email.
class Telemetry {
  static final _analytics = FirebaseAnalytics.instance;

  static Future<void> setUser(String? userId) async {
    await _analytics.setUserId(id: userId);
    await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
  }

  /// Records an error that didn't crash the app but shouldn't happen.
  static void recordError(Object error, StackTrace stack, {String? reason}) {
    if (kDebugMode) {
      debugPrint('[telemetry] $reason: $error');
      return;
    }
    FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
  }

  static Future<void> puzzleFinished({required bool solved, required bool offline}) =>
      _analytics.logEvent(name: 'puzzle_finished', parameters: {'solved': solved ? 1 : 0, 'offline': offline ? 1 : 0});

  static Future<void> puzzlesSynced({required int uploaded, required int overLimit}) =>
      _analytics.logEvent(name: 'puzzles_synced', parameters: {'uploaded': uploaded, 'over_limit': overLimit});

  /// Spec §4: data used by the app's API calls this session, sent when the app goes to the
  /// background.
  static Future<void> sessionData({required int bytes, required DateTime since}) => _analytics.logEvent(
        name: 'session_data',
        parameters: {'kb': bytes ~/ 1024, 'minutes': DateTime.now().difference(since).inMinutes},
      );

  // Spec §10: retention of players who hit a disconnect in their first games. The online game
  // screen calls these; `gamesPlayed` lets the cohort be filtered to the first three games.
  static Future<void> gameDisconnected({required String gameId, required int gamesPlayed}) =>
      _analytics.logEvent(name: 'game_disconnect', parameters: {'game_id': gameId, 'games_played': gamesPlayed});

  static Future<void> gameReconnected({required String gameId, required int awayMs}) =>
      _analytics.logEvent(name: 'game_reconnect', parameters: {'game_id': gameId, 'away_ms': awayMs});
}
