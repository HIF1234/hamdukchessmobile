import 'dart:async';

import 'package:quick_actions/quick_actions.dart';

/// Long-press the app icon: Play 5 min, Daily puzzle, Host a local tournament. All three
/// reuse the launcher icon (ic_launcher_monochrome) -- distinct per-shortcut icons would
/// need new drawable assets this change doesn't add.
enum AppShortcut { play5, dailyPuzzle, hostLocal }

class AppShortcuts {
  static final _plugin = QuickActions();
  static AppShortcut? _pending;
  static final _tapped = StreamController<AppShortcut>.broadcast();

  /// Fires for a shortcut tapped while the app is already running (HomeShell is mounted
  /// and listening). A cold-start tap instead lands in [take], checked once HomeShell's
  /// first frame is up.
  static Stream<AppShortcut> get onTap => _tapped.stream;

  static Future<void> start() async {
    await _plugin.initialize((type) {
      final shortcut = _fromType(type);
      if (shortcut == null) return;
      _pending = shortcut;
      _tapped.add(shortcut);
    });
    await _plugin.setShortcutItems(const [
      ShortcutItem(type: 'play5', localizedTitle: 'Play 5 min', icon: 'ic_launcher_monochrome'),
      ShortcutItem(type: 'daily_puzzle', localizedTitle: 'Daily puzzle', icon: 'ic_launcher_monochrome'),
      ShortcutItem(type: 'host_local', localizedTitle: 'Host a local tournament', icon: 'ic_launcher_monochrome'),
    ]);
  }

  static AppShortcut? _fromType(String type) => switch (type) {
        'play5' => AppShortcut.play5,
        'daily_puzzle' => AppShortcut.dailyPuzzle,
        'host_local' => AppShortcut.hostLocal,
        _ => null,
      };

  /// Null once consumed, so a cold start acts on it at most once. Checked right after
  /// launch (the shortcut that started the app) and whenever one is tapped while running.
  static AppShortcut? take() {
    final v = _pending;
    _pending = null;
    return v;
  }
}
