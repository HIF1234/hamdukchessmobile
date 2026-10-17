import 'package:flutter/foundation.dart';

import 'storage.dart';

/// Player settings kept on the device.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  static const _key = 'settings';

  /// Low-data mode (spec §4): no avatars or other pictures, no animations.
  bool lowData = false;

  /// One of [appLanguages]' codes. Chosen at onboarding, changeable in Settings. Every
  /// language currently renders in English -- there's no translated copy yet -- so this is
  /// just the stored preference, ready for when real translations exist.
  String language = 'en';

  /// Off by default: skips the promotion picker and always promotes to a queen.
  bool autoQueen = false;

  /// On by default: a light tap on each move, stronger on captures and check, a buzz when
  /// the opponent moves.
  bool vibration = true;

  /// Off by default: no ratings shown during games, for nervous players.
  bool hideRatings = false;

  /// Off by default: a tick to confirm each move before it's sent. GameScreen forces this
  /// on for daily (correspondence) games regardless of this setting.
  bool moveConfirmation = false;

  /// Off by default: pieces hidden, as on the website.
  bool blindfold = false;

  /// On by default: move/capture/check/etc. sounds. See lib/core/game_sounds.dart.
  bool sound = true;

  /// On by default for bot games: takebacks, a hint button, and hanging pieces
  /// highlighted. Turning it off is how a stronger player "plays for real" against bots --
  /// wins with it on don't count toward the bot ladder.
  bool assistedMode = true;

  Future<void> load() async {
    final j = await (await JsonStore.open()).read(_key);
    if (j is Map) {
      lowData = j['lowData'] == true;
      language = j['language'] as String? ?? 'en';
      autoQueen = j['autoQueen'] == true;
      vibration = j['vibration'] != false;
      hideRatings = j['hideRatings'] == true;
      moveConfirmation = j['moveConfirmation'] == true;
      blindfold = j['blindfold'] == true;
      sound = j['sound'] != false;
      assistedMode = j['assistedMode'] != false;
    }
  }

  Future<void> setLowData(bool v) async {
    lowData = v;
    notifyListeners();
    await _save();
  }

  Future<void> setLanguage(String v) async {
    language = v;
    notifyListeners();
    await _save();
  }

  Future<void> setAutoQueen(bool v) async {
    autoQueen = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVibration(bool v) async {
    vibration = v;
    notifyListeners();
    await _save();
  }

  Future<void> setHideRatings(bool v) async {
    hideRatings = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMoveConfirmation(bool v) async {
    moveConfirmation = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBlindfold(bool v) async {
    blindfold = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSound(bool v) async {
    sound = v;
    notifyListeners();
    await _save();
  }

  Future<void> setAssistedMode(bool v) async {
    assistedMode = v;
    notifyListeners();
    await _save();
  }

  Future<void> _save() => (JsonStore.open()).then((s) => s.write(_key, {
        'lowData': lowData,
        'language': language,
        'autoQueen': autoQueen,
        'vibration': vibration,
        'hideRatings': hideRatings,
        'moveConfirmation': moveConfirmation,
        'blindfold': blindfold,
        'sound': sound,
        'assistedMode': assistedMode,
      }));
}

/// Onboarding's "first question" and Settings > Language. Every option renders in English
/// today; see [AppSettings.language].
const appLanguages = {
  'en': 'English',
  'pcm': 'Pidgin',
  'yo': 'Yoruba',
  'ha': 'Hausa',
  'ig': 'Igbo',
};

/// Counts the app's own API traffic this session (spec §4: measure MB per session).
/// Realtime traffic isn't included; it's small by comparison (one row per move).
class DataMeter {
  static int bytes = 0;
  static final started = DateTime.now();

  // Rough size of the HTTP headers each request and response carries.
  static const _headerOverhead = 600;

  static void add(int bodyBytes) => bytes += bodyBytes + _headerOverhead;

  static String get label {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
