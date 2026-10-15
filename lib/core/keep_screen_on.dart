import 'package:wakelock_plus/wakelock_plus.dart';

/// The screen stays on during any game (online, bot, local) or review, and returns to
/// normal afterwards. Reference-counted since one game screen can push another on top of
/// itself (e.g. Review over a finished game) -- wakelock_plus itself has no concept of
/// "still needed by someone else", it's just a single on/off switch.
class KeepScreenOn {
  static int _count = 0;

  /// Call once from a screen's initState.
  static void push() {
    _count++;
    if (_count == 1) WakelockPlus.enable();
  }

  /// Call once from the same screen's dispose.
  static void pop() {
    _count = (_count - 1).clamp(0, 1 << 30);
    if (_count == 0) WakelockPlus.disable();
  }
}
