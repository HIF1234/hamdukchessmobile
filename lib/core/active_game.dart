import 'storage.dart';

/// Whichever game, online or vs a bot, is currently open -- so if the app closes mid-game,
/// reopening it returns straight there instead of the tab list. Cleared once the game ends.
sealed class ActiveGame {
  static const _key = 'active_game';

  static Future<void> setOnline(String gameId) async =>
      (await JsonStore.open()).write(_key, {'type': 'online', 'gameId': gameId});

  static Future<void> setBot({
    required String botId,
    required bool playWhite,
    required List<String> sanMoves,
    required bool assisted,
    String? timeControl,
    int? whiteMs,
    int? blackMs,
  }) async =>
      (await JsonStore.open()).write(_key, {
        'type': 'bot',
        'botId': botId,
        'playWhite': playWhite,
        'moves': sanMoves,
        'assisted': assisted,
        'timeControl': ?timeControl,
        'whiteMs': ?whiteMs,
        'blackMs': ?blackMs,
      });

  static Future<void> clear() async => (await JsonStore.open()).write(_key, null);

  /// Null once consumed (or when nothing's in progress), so a cold start resumes at most once.
  static Future<ActiveGame?> takePending() async {
    final pending = await peek();
    if (pending != null) await clear();
    return pending;
  }

  /// Same as [takePending] but doesn't clear it -- for Play's continue card, which needs to
  /// keep showing a bot game in progress across rebuilds, not just once.
  static Future<ActiveGame?> peek() async {
    final store = await JsonStore.open();
    final raw = await store.read(_key);
    if (raw is! Map) return null;
    return switch (raw['type']) {
      'online' => OnlineActiveGame(raw['gameId'] as String),
      'bot' => BotActiveGame(
          botId: raw['botId'] as String,
          playWhite: raw['playWhite'] as bool,
          sanMoves: (raw['moves'] as List).cast<String>(),
          assisted: raw['assisted'] as bool? ?? true,
          timeControl: raw['timeControl'] as String?,
          whiteMs: (raw['whiteMs'] as num?)?.toInt(),
          blackMs: (raw['blackMs'] as num?)?.toInt(),
        ),
      _ => null,
    };
  }
}

class OnlineActiveGame extends ActiveGame {
  OnlineActiveGame(this.gameId);
  final String gameId;
}

class BotActiveGame extends ActiveGame {
  BotActiveGame({
    required this.botId,
    required this.playWhite,
    required this.sanMoves,
    required this.assisted,
    this.timeControl,
    this.whiteMs,
    this.blackMs,
  });
  final String botId;
  final bool playWhite;
  final List<String> sanMoves;
  final bool assisted;

  /// Null means untimed. Remaining ms are resumed as-is (the clock doesn't run while the
  /// app is closed -- there's no server to keep authoritative time for an offline bot game).
  final String? timeControl;
  final int? whiteMs;
  final int? blackMs;
}
