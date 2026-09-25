import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON files in the app's private documents folder. Used for everything the app
/// needs offline: the backend config, puzzle packs and results waiting to sync.
class JsonStore {
  JsonStore._(this._dir);
  final Directory _dir;

  static JsonStore? _instance;
  static Future<JsonStore> open() async =>
      _instance ??= JsonStore._(await getApplicationDocumentsDirectory());

  /// For tests: store files in [dir].
  static JsonStore at(Directory dir) => JsonStore._(dir);

  File _file(String name) => File('${_dir.path}/$name.json');

  Future<Object?> read(String name) async {
    final f = _file(name);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } on FormatException {
      return null; // a torn write; treat as missing
    }
  }

  /// Writes atomically (temp file + rename) so a crash never leaves half a file.
  Future<void> write(String name, Object? value) async {
    final f = _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(f.path);
  }
}
