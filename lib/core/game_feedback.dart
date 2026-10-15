import 'package:flutter/services.dart';

import 'settings.dart';

/// What just happened on the board, for the matching sound + haptic.
enum GameEvent { move, capture, check, castle, promotion, gameStart, gameEnd, opponentMoved, lowTimeTick }

/// Sound + vibration for game events, each gated on its own setting.
///
/// Sound is placeholder system clicks/alerts for now -- there's no real move/capture/
/// castle/etc. audio bundled with the app. SystemSound already respects the phone's silent
/// switch on its own, which is exactly the spec's "quiet when the phone is on silent".
/// Swap in real files later: drop them in `assets/sounds/<name>.mp3`, register them in
/// pubspec.yaml, and replace the SystemSound.play calls below with
/// `AudioPlayer().play(AssetSource('sounds/<name>.mp3'))` (audioplayers is already a
/// dependency, just unused until there's something real to play).
/// "Nxf3+" -> check (also mate), "O-O"/"O-O-O" -> castle, "exd5" -> capture, else a plain
/// move -- [mine] picks between [GameEvent.move] and [GameEvent.opponentMoved] for a plain one.
GameEvent eventForSan(String san, {required bool mine}) {
  if (san.contains('#') || san.contains('+')) return GameEvent.check;
  if (san.startsWith('O-O')) return GameEvent.castle;
  if (san.contains('x')) return GameEvent.capture;
  return mine ? GameEvent.move : GameEvent.opponentMoved;
}

class GameFeedback {
  static Future<void> on(GameEvent event) async {
    if (AppSettings.instance.sound) await _sound(event);
    if (AppSettings.instance.vibration) await _haptic(event);
  }

  static Future<void> _sound(GameEvent event) {
    final alert = event == GameEvent.check || event == GameEvent.gameEnd || event == GameEvent.lowTimeTick;
    return SystemSound.play(alert ? SystemSoundType.alert : SystemSoundType.click);
  }

  static Future<void> _haptic(GameEvent event) => switch (event) {
        GameEvent.capture || GameEvent.check => HapticFeedback.mediumImpact(),
        GameEvent.opponentMoved => HapticFeedback.vibrate(),
        GameEvent.gameEnd => HapticFeedback.heavyImpact(),
        _ => HapticFeedback.lightImpact(),
      };
}
