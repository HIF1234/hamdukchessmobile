import '../core/api.dart';
import '../core/storage.dart';
import 'puzzle_session.dart';

/// Offline puzzles: a downloaded pack, the ones already done, and results waiting to upload.
/// Everything is saved on the device, so the app works on a bus with no data.
class PuzzleStore {
  PuzzleStore(this._store, {this.theme});
  final JsonStore _store;

  /// Null for the rated mix; otherwise a Lichess theme such as "fork" or "mateIn2".
  final String? theme;

  String get _packKey => theme == null ? 'puzzle_pack' : 'puzzle_pack_$theme';
  static const _queueKey = 'puzzle_queue';
  static const refillBelow = 10;

  List<Puzzle> _pack = [];

  // One upload queue for every theme, shared by all stores, so switching themes never
  // loses a result.
  static List<Map<String, dynamic>>? _sharedQueue;
  List<Map<String, dynamic>> get _queue => _sharedQueue!;
  int? rating; // last rating the server told us
  int maxPack = 30;

  int get remaining => _pack.length;
  int get pendingUploads => _queue.length;

  // How many puzzles this device has solved today, across every theme; resets at local
  // midnight. Puzzles are solved offline-first, so this device is the real source of truth
  // for "today", not the server's own record of when results were finally uploaded.
  static const _solvedTodayKey = 'puzzles_solved_today';
  static int? _sharedSolvedToday;
  static String? _sharedSolvedTodayDate;
  int get solvedToday => _sharedSolvedToday ?? 0;

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static Future<PuzzleStore> open([JsonStore? store, String? theme]) async {
    final s = PuzzleStore(store ?? await JsonStore.open(), theme: theme);
    await s._load();
    return s;
  }

  /// For tests: forget the in-memory queue so it's read from storage again.
  static void resetForTests() {
    _sharedQueue = null;
    _sharedSolvedToday = null;
    _sharedSolvedTodayDate = null;
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
    if (_sharedQueue == null) {
      final q = await _store.read(_queueKey);
      _sharedQueue = q is List ? q.map((e) => (e as Map).cast<String, dynamic>()).toList() : [];
    }
    if (_sharedSolvedToday == null) {
      final raw = await _store.read(_solvedTodayKey);
      final today = _todayKey();
      _sharedSolvedToday = raw is Map && raw['date'] == today ? (raw['count'] as num?)?.toInt() ?? 0 : 0;
      _sharedSolvedTodayDate = today;
    }
  }

  Future<void> _bumpSolvedToday() async {
    final today = _todayKey();
    if (_sharedSolvedTodayDate != today) {
      _sharedSolvedToday = 0;
      _sharedSolvedTodayDate = today;
    }
    _sharedSolvedToday = (_sharedSolvedToday ?? 0) + 1;
    await _store.write(_solvedTodayKey, {'date': today, 'count': _sharedSolvedToday});
  }

  Future<void> _savePack() => _store.write(_packKey, {
        'puzzles': _pack.map((p) => p.toJson()).toList(),
        'rating': rating,
        'maxPack': maxPack,
      });

  Puzzle? get next => _pack.isEmpty ? null : _pack.first;

  /// Records a finished puzzle locally and removes it from the pack.
  /// [hintsUsed] (0-2) dampens the rating gain on solve: the server halves it (4+ ply
  /// puzzles) or zeroes it (shorter ones) for 1 hint, and always zeroes it for 2.
  Future<void> record(Puzzle p, bool success, {int hintsUsed = 0}) async {
    _pack.removeWhere((x) => x.id == p.id);
    _queue.add({'puzzleId': p.id, 'success': success, 'hintsUsed': hintsUsed});
    await Future.wait([_savePack(), _store.write(_queueKey, _queue), if (success) _bumpSolvedToday()]);
  }

  /// Uploads waiting results (oldest first), then tops the pack up unless [allowRefill] is
  /// false (the background Wi-Fi-only auto top-up passes false on cellular -- uploads are
  /// tiny and always welcome, but a 30-puzzle pack download isn't something to do silently
  /// on mobile data). Safe to call any time; on no connection it leaves everything in place
  /// for next time.
  Future<SyncResult> sync(Api api, {bool allowRefill = true}) async {
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
      if (allowRefill && _pack.length < refillBelow) {
        final res = await api.get('/puzzles/pack', {'count': '$maxPack', 'theme': ?theme}) as Map;
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
