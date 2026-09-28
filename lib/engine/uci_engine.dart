import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One line of Stockfish's analysis: a candidate move and its score in centipawns from the
/// side to move's point of view (mate scores become ±100000).
class Pv {
  const Pv(this.move, this.score);
  final String move;
  final int score;
}

/// Stockfish running as a separate program, spoken to only through UCI text commands on
/// its standard input and output. The engine is never linked into the app (GPL: see
/// engine/build.sh and NOTICE.md).
class UciEngine {
  UciEngine._(this._process) {
    _process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine);
    _process.stderr.drain<void>();
  }

  final Process _process;
  final _waiters = <bool Function(String)>[];
  Completer<(String, List<Pv>)>? _search;
  final _pvs = <int, Pv>{};
  bool _closed = false;

  /// Starts the engine at [path] and waits until it's ready. Small hash and one thread keep
  /// it light on 2 GB phones.
  static Future<UciEngine> start(String path) async {
    final e = UciEngine._(await Process.start(path, const []));
    e._send('uci');
    await e._until((l) => l == 'uciok');
    e._send('setoption name Hash value 16');
    e._send('setoption name Threads value 1');
    await e.ready();
    return e;
  }

  Future<void> ready() {
    _send('isready');
    return _until((l) => l == 'readyok');
  }

  /// Searches [fen] and returns Stockfish's choice plus its top [multiPv] lines.
  Future<(String bestMove, List<Pv> lines)> analyse(
    String fen, {
    required int depth,
    required int movetimeMs,
    int multiPv = 3,
  }) async {
    if (_search != null) throw StateError('A search is already running');
    _pvs.clear();
    final c = _search = Completer<(String, List<Pv>)>();
    // Without this, Stockfish's hash table and move-ordering history from the previous
    // position leak into this search: on a small 16 MB hash they don't just fail to help,
    // they bias which line gets explored, which can swing the depth-14 eval by 50-100cp on
    // an unrelated position (seen concretely on 1.e4 e5 review scores). ucinewgame resets both.
    _send('ucinewgame');
    _send('setoption name MultiPV value $multiPv');
    _send('position fen $fen');
    _send('go depth $depth movetime $movetimeMs');
    return c.future;
  }

  void _onLine(String line) {
    for (final w in List.of(_waiters)) {
      if (w(line)) _waiters.remove(w);
    }
    if (_search == null) return;
    final m = RegExp(r'multipv (\d+) score (cp|mate) (-?\d+).* pv (\S+)').firstMatch(line);
    if (m != null) {
      final raw = int.parse(m.group(3)!);
      final score = m.group(2) == 'mate' ? raw.sign * 100000 : raw;
      _pvs[int.parse(m.group(1)!)] = Pv(m.group(4)!, score);
    }
    if (line.startsWith('bestmove')) {
      final best = line.split(' ')[1];
      final lines = (_pvs.keys.toList()..sort()).map((k) => _pvs[k]!).toList();
      final c = _search!;
      _search = null;
      c.complete((best, lines));
    }
  }

  Future<void> _until(bool Function(String) test) {
    final c = Completer<void>();
    _waiters.add((l) {
      if (!test(l)) return false;
      c.complete();
      return true;
    });
    return c.future.timeout(const Duration(seconds: 10));
  }

  void _send(String cmd) {
    if (!_closed) _process.stdin.writeln(cmd);
  }

  /// Stops the engine and ends the process.
  Future<void> dispose() async {
    if (_closed) return;
    _send('quit');
    _closed = true;
    await _process.stdin.close().catchError((_) {});
    // Make sure it's gone even if it didn't quit cleanly.
    Future.delayed(const Duration(seconds: 1), () => _process.kill());
  }
}
