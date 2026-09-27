import '../core/api.dart';
import '../core/storage.dart';

/// Finished bot games waiting to upload. Bots play offline, so results queue on the phone
/// and go to /bot-games when there's a connection.
class BotResults {
  static const _key = 'bot_queue';

  static Future<void> add(Map<String, dynamic> result) async {
    final store = await JsonStore.open();
    final q = ((await store.read(_key)) as List?)?.cast<Map>().toList() ?? [];
    q.add(result);
    await store.write(_key, q);
  }

  /// Uploads what's queued, oldest first. Stops quietly when offline.
  static Future<void> sync() async {
    final store = await JsonStore.open();
    final q = ((await store.read(_key)) as List?)?.cast<Map>().toList() ?? [];
    while (q.isNotEmpty) {
      try {
        await Api.instance.post('/bot-games', q.first);
      } on ApiError catch (e) {
        if (e.isNetwork) break; // try again later
        // Rejected (e.g. a Plus bot after the membership lapsed): drop it rather than retry forever.
      }
      q.removeAt(0);
      await store.write(_key, q);
    }
  }
}
