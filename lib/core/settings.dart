import 'package:flutter/foundation.dart';

import 'storage.dart';

/// Player settings kept on the device.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  static const _key = 'settings';

  /// Low-data mode (spec §4): no avatars or other pictures, no animations.
  bool lowData = false;

  Future<void> load() async {
    final j = await (await JsonStore.open()).read(_key);
    if (j is Map) lowData = j['lowData'] == true;
  }

  Future<void> setLowData(bool v) async {
    lowData = v;
    notifyListeners();
    await (await JsonStore.open()).write(_key, {'lowData': lowData});
  }
}

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
