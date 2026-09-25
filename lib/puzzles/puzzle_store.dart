import '../core/api.dart';
import '../core/storage.dart';
import 'puzzle_session.dart';

/// Offline puzzles: a downloaded pack, the ones already done, and results waiting to upload.
/// Everything is saved on the device, so the app works on a bus with no data.
class PuzzleStore {
  PuzzleStore(this._store);
  final JsonStore _store;

  static const _packKey = 'puzzle_pack';
  static const _queueKey = 'puzzle_queue';
  static const refillBelow = 10;

  List<Puzzle> _pack = [];
  List<Map<String, dynamic>> _queue = [];
  int? rating; // last rating the server told us
  int maxPack = 30;

  int get remaining => _pack.length;
  int get pendingUploads => _queue.length;

  static Future<PuzzleStore> open([JsonStore? store]) async {
    final s = PuzzleStore(store ?? await JsonStore.open());
    await s._load();
    return s;
  }

  Future<void> _load() async {
    final pack = await _store.read(_packKey);
    if (pack is Map) {
      _pack = ((pack['puzzles'] as List?) ?? const [])
          .map((p) => Puzzle.fromJson((p as Map).cast<String, dynamic>()))
          .toList();
      rating = (pack['rating'] as num?)?.toInt();
      maxPack = (pack['maxPack'] as num?)?.toInt() ?? maxPack;
    }
    final q = await _store.read(_queueKey);
    if (q is List) _queue = q.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> _savePack() => _store.write(_packKey, {
        'puzzles': _pack.map((p) => p.toJson()).toList(),
        'rating': rating,
        'maxPack': maxPack,
      });

  Puzzle? get next => _pack.isEmpty ? null : _pack.first;

  /// Records a finished puzzle locally and removes it from the pack.
  Future<void> record(Puzzle p, bool success) async {
    _pack.removeWhere((x) => x.id == p.id);
    _queue.add({'puzzleId': p.id, 'success': success});
    await Future.wait([_savePack(), _store.write(_queueKey, _queue)]);
  }

  /// Uploads waiting results (oldest first), then tops the pack up. Safe to call any time;
  /// on no connection it leaves everything in place for next time.
  Future<SyncResult> sync(Api api) async {
    var uploaded = 0;
    var overLimit = 0;
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.take(200).toList();
        final res = await api.post('/puzzles/sync', {'attempts': batch}) as Map;
        final results = (res['results'] as List).cast<Map>();
        for (final r in results) {
          if (r['status'] == 'recorded') {
            uploaded++;
            rating = (r['rating'] as num?)?.toInt() ?? rating;
          } else if (r['status'] == 'limit') {
            overLimit++;
          }
        }
        // Every result in the batch is settled (recorded, over the free limit, or rejected).
        _queue.removeRange(0, batch.length);
        await _store.write(_queueKey, _queue);
      }
      if (_pack.length < refillBelow) {
        final res = await api.get('/puzzles/pack', {'count': '$maxPack'}) as Map;
        maxPack = (res['maxPack'] as num).toInt();
        rating = (res['rating'] as num?)?.toInt() ?? rating;
        final known = _pack.map((p) => p.id).toSet();
        _pack.addAll(((res['puzzles'] as List).cast<Map>())
            .map((p) => Puzzle.fromJson(p.cast<String, dynamic>()))
            .where((p) => !known.contains(p.id)));
        await _savePack();
      }
      return SyncResult(uploaded: uploaded, overLimit: overLimit);
    } on ApiError catch (e) {
      return SyncResult(uploaded: uploaded, overLimit: overLimit, error: e);
    }
  }
}

class SyncResult {
  SyncResult({required this.uploaded, required this.overLimit, this.error});
  final int uploaded;
  final int overLimit;
  final ApiError? error;
  bool get offline => error?.isNetwork ?? false;
}
