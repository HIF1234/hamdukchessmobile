import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/telemetry.dart';
import 'puzzle_session.dart';
import 'puzzle_store.dart';

/// Rated puzzles that work offline: solve from the downloaded pack; results upload when
/// the phone is back online.
class PuzzlesScreen extends StatefulWidget {
  const PuzzlesScreen({super.key});

  @override
  State<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

class _PuzzlesScreenState extends State<PuzzlesScreen> {
  PuzzleStore? _store;
  PuzzleSession? _session;
  bool _syncing = false;
  bool _showHint = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _init();
    // Sync whenever a connection comes back.
    Connectivity().onConnectivityChanged.listen((r) {
      if (!r.contains(ConnectivityResult.none)) _sync();
    });
  }

  Future<void> _init() async {
    final store = await PuzzleStore.open();
    setState(() {
      _store = store;
      _nextPuzzle();
    });
    await _sync();
  }

  Future<void> _sync() async {
    final store = _store;
    if (store == null || _syncing) return;
    setState(() => _syncing = true);
    final r = await store.sync(Api.instance);
    if (r.uploaded > 0 || r.overLimit > 0) {
      Telemetry.puzzlesSynced(uploaded: r.uploaded, overLimit: r.overLimit);
    }
    if (!mounted) return;
    setState(() {
      _syncing = false;
      if (r.overLimit > 0) {
        _note = '${r.overLimit} solved offline after your 20 free puzzles today counted as practice. '
            'Hamduk Plus is unlimited.';
      } else if (r.error != null && !r.offline) {
        _note = r.error!.message;
      }
      if (_session == null) _nextPuzzle();
    });
  }

  void _nextPuzzle() {
    final p = _store?.next;
    _session = p == null ? null : PuzzleSession(p);
    _showHint = false;
  }

  bool _onMove(String from, String to, String? promo) {
    final s = _session;
    if (s == null) return false;
    final ok = s.tryMove(from, to, promo);
    if (!ok) return false;
    setState(() {});
    if (s.awaitingReply) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(s.playReply);
        _finishIfDone(s);
      });
    } else {
      _finishIfDone(s);
    }
    return true;
  }

  Future<void> _finishIfDone(PuzzleSession s) async {
    if (s.status == PuzzleStatus.playing) return;
    await _store!.record(s.puzzle, s.status == PuzzleStatus.solved);
    final online = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
    Telemetry.puzzleFinished(solved: s.status == PuzzleStatus.solved, offline: !online);
    setState(() {});
    _sync(); // uploads straight away when online; otherwise it waits
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final store = _store;
    final s = _session;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('Puzzles', style: t.textTheme.headlineSmall),
          const Spacer(),
          if (store?.rating != null) Text('Rating ${store!.rating}', style: t.textTheme.titleMedium),
        ]),
        const SizedBox(height: 4),
        Text(
          store == null
              ? 'Loading…'
              : '${store.remaining} ready offline'
                  '${store.pendingUploads > 0 ? ' · ${store.pendingUploads} waiting to upload' : ''}'
                  '${_syncing ? ' · syncing…' : ''}',
          style: t.textTheme.bodySmall,
        ),
        if (_note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_note!)),
        const SizedBox(height: 12),
        if (s == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(children: [
              const Text('No puzzles downloaded yet. Connect to the internet to get a pack.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _sync, child: const Text('Download puzzles')),
            ]),
          )
        else ...[
          ChessBoardView(
            key: ValueKey(s.puzzle.id),
            fen: s.fen,
            whiteAtBottom: s.whiteToSolve,
            lastMove: s.lastMove,
            hintSquare: _showHint ? s.hint : null,
            onMove: s.status == PuzzleStatus.playing && !s.awaitingReply ? _onMove : null,
          ),
          const SizedBox(height: 12),
          Text(
            switch (s.status) {
              PuzzleStatus.playing => '${s.whiteToSolve ? 'White' : 'Black'} to play · rated ${s.puzzle.rating}',
              PuzzleStatus.solved => 'Solved!',
              PuzzleStatus.failed => 'Not quite. The best move was ${s.puzzle.solution.first}.',
            },
            style: t.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (s.status == PuzzleStatus.playing)
              TextButton(onPressed: () => setState(() => _showHint = true), child: const Text('Hint')),
            const Spacer(),
            if (s.status != PuzzleStatus.playing)
              FilledButton(onPressed: () => setState(_nextPuzzle), child: const Text('Next puzzle')),
          ]),
        ],
      ],
    );
  }
}
