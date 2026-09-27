import 'package:flutter/services.dart';

/// Facts about the phone, from the Android side (MainActivity, channel "hamduk/device").
class Device {
  static const _channel = MethodChannel('hamduk/device');

  /// Path of the bundled Stockfish program.
  static Future<String> stockfishPath() async =>
      '${await _channel.invokeMethod<String>('nativeLibraryDir')}/libstockfish.so';

  static int? _ram;

  /// Total memory in MB (cached).
  static Future<int> totalRamMb() async => _ram ??= await _channel.invokeMethod<int>('totalRamMb') ?? 0;

  /// Phones with under 3 GB of memory skip the heaviest bots (spec §3: stay smooth on 2 GB
  /// phones) until they've been tested on one.
  static Future<bool> isLowMemory() async {
    final ram = await totalRamMb();
    return ram > 0 && ram < 3000;
  }
}
