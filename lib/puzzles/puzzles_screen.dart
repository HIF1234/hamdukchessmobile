import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/telemetry.dart';
import '../core/theme.dart';
import 'puzzle_session.dart';
import 'puzzle_store.dart';
import 'storm_screen.dart';
import 'theme_stats_screen.dart';

/// Rated puzzles that work offline: solve from the downloaded pack; results upload when
/// the phone is back online.
class PuzzlesScreen extends StatefulWidget {
  const PuzzlesScreen({super.key});

  @override
  State<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

/// Themes offered for practice, most useful first. Keys are the Lichess theme tags on our
/// puzzles.
const puzzleThemes = <(String?, String)>[
  (null, 'Rated mix'),
  ('mateIn1', 'Mate in 1'),
  ('mateIn2', 'Mate in 2'),
  ('fork', 'Forks'),
  ('pin', 'Pins'),
  ('skewer', 'Skewers'),
  ('hangingPiece', 'Hanging pieces'),
  ('discoveredAttack', 'Discovered attacks'),
  ('backRankMate', 'Back rank'),
  ('sacrifice', 'Sacrifices'),
  ('deflection', 'Deflection'),
  ('kingsideAttack', 'Attacking the king'),
  ('mateIn3', 'Mate in 3'),
  ('endgame', 'Endgames'),
  ('promotion', 'Promotion'),
];

class _PuzzlesScreenState extends State<PuzzlesScreen> {
  PuzzleStore? _store;
  String? _theme;
  PuzzleSession? _session;
  bool _syncing = false;
  String? _note;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _init();
    _loadStreak();
    // Sync whenever a connection comes back. Uploading results is tiny and always welcome;
    // the pack top-up is a bigger download, so this background trigger only does that part
    // on WiFi -- an explicit action elsewhere (opening the screen, hitting the limit banner)
    // still refills regardless of connection, since the player is actively waiting on it.
    Connectivity().onConnectivityChanged.listen((r) {
      if (r.contains(ConnectivityResult.none)) return;
      _sync(allowRefill: r.contains(ConnectivityResult.wifi));
    });
  }

  Future<void> _loadStreak() async {
    try {
      final me = await Api.instance.get('/me') as Map;
      final streak = ((me['puzzles'] as Map?)?['current_streak'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() => _streak = streak);
    } catch (_) {
      // Offline or failed: the hero just shows no streak badge.
    }
  }

  Future<void> _init() async {
    final store = await PuzzleStore.open(null, _theme);
    if (!mounted) return;
    setState(() {
      _store = store;
      _note = null;
      _nextPuzzle();
    });
    await _sync();
  }

  Future<void> _pickTheme(String? theme) async {
    if (theme == _theme) return;
    setState(() {
      _theme = theme;
      _store = null;
      _session = null;
    });
    await _init();
  }

  Future<void> _sync({bool allowRefill = true}) async {
    final store = _store;
    if (store == null || _syncing) return;
    setState(() => _syncing = true);
    final r = await store.sync(Api.instance, allowRefill: allowRefill);
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
    await _store!.record(s.puzzle, s.status == PuzzleStatus.solved, hintsUsed: s.maxHintLevel);
    final online = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
    Telemetry.puzzleFinished(solved: s.status == PuzzleStatus.solved, offline: !online);
    setState(() {});
    _sync(); // uploads straight away when online; otherwise it waits
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final store = _store;
    final s = _session;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const ScreenHeader(title: 'Puzzles', subtitle: 'Rated tactics, solved offline'),
        Padding(
          padding: const EdgeInsets.fromLTRB(HcSpace.s4, 0, HcSpace.s4, HcSpace.s4),
          child: HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: HeroCard.overline('Puzzle rating')),
                  if (_streak > 0) ...[
                    HcBadge.onHero('$_streak day streak', icon: Icons.local_fire_department_rounded),
                    const SizedBox(width: HcSpace.s2),
                  ],
                  IconButton(
                    icon: const Icon(Icons.bolt_rounded, color: HcColors.onForest),
                    tooltip: 'Puzzle Storm',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StormScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.insights_rounded, color: HcColors.onForest),
                    tooltip: 'Stats by theme',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemeStatsScreen())),
                  ),
                ]),
                const SizedBox(height: HcSpace.s1),
                Text(
                  store?.rating != null ? hcNumber(store!.rating!) : '—',
                  style: HcText.ratingXl.copyWith(color: context.hc.gold),
                ),
                const SizedBox(height: HcSpace.s4),
                Row(children: [
                  HeroCard.tile(label: 'Solved today', value: store == null ? '—' : '${store.solvedToday}'),
                  const SizedBox(width: HcSpace.s2),
                  HeroCard.tile(label: 'Ready offline', value: store == null ? '—' : '${store.remaining}'),
                  if (store?.remainingToday != null) ...[
                    const SizedBox(width: HcSpace.s2),
                    HeroCard.tile(label: 'Left today', value: '${store!.remainingToday}'),
                  ],
                ]),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (key, label) in puzzleThemes)
                    Padding(
                      padding: const EdgeInsets.only(right: HcSpace.s2),
                      child: ChoiceChip(label: Text(label), selected: _theme == key, onSelected: (_) => _pickTheme(key)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: HcSpace.s4),
            if (s == null)
              EmptyState(
                icon: Icons.extension_rounded,
                title: 'No puzzles downloaded yet',
                body: 'Connect to the internet to get a pack. After that, puzzles work offline.',
                actionLabel: 'Download puzzles',
                actionIcon: Icons.download_rounded,
                onAction: _sync,
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(HcRadius.board),
                child: ChessBoardView(
                  key: ValueKey(s.puzzle.id),
                  fen: s.fen,
                  whiteAtBottom: s.whiteToSolve,
                  lastMove: s.lastMove,
                  lastMoveSan: s.lastSan,
                  hintSquare: s.hintFrom,
                  arrow: s.hintTo != null ? (s.hintFrom!, s.hintTo!) : null,
                  onMove: s.status == PuzzleStatus.playing && !s.awaitingReply ? _onMove : null,
                  animate: !AppSettings.instance.lowData,
                ),
              ),
              const SizedBox(height: HcSpace.s3),
              Text(
                switch (s.status) {
                  PuzzleStatus.playing => '${s.whiteToSolve ? 'White' : 'Black'} to play · rated ${s.puzzle.rating}',
                  PuzzleStatus.solved => s.maxHintLevel >= 2
                      ? 'Solved! No rating gained (move was shown).'
                      : s.maxHintLevel == 1
                          ? 'Solved! Reduced rating gain (hint used).'
                          : 'Solved!',
                  PuzzleStatus.failed => 'Not quite. The best move was ${s.puzzle.solution.first}.',
                },
                style: HcText.titleMd.copyWith(color: hc.ink),
              ),
              const SizedBox(height: HcSpace.s3),
              Row(children: [
                if (s.status == PuzzleStatus.playing)
                  TextButton(
                    onPressed: s.hintLevel >= 2 ? null : () => setState(s.showHint),
                    child: Text(s.hintLevel == 0 ? 'Hint' : 'Show move'),
                  ),
                const Spacer(),
                if (s.status != PuzzleStatus.playing)
                  FilledButton(onPressed: () => setState(_nextPuzzle), child: const Text('Next puzzle')),
              ]),
            ],
            const SizedBox(height: HcSpace.s4),
            Text(
              store == null
                  ? 'Loading…'
                  : '${store.remaining} ready offline'
                      '${store.pendingUploads > 0 ? ' · ${store.pendingUploads} waiting to upload' : ''}'
                      '${_syncing ? ' · syncing…' : ''}',
              style: HcText.bodySm.copyWith(color: hc.ink3),
            ),
            if (_note != null) Padding(padding: const EdgeInsets.only(top: HcSpace.s2), child: Text(_note!, style: HcText.bodySm.copyWith(color: hc.ink2))),
            const SizedBox(height: HcSpace.s4),
          ]),
        ),
      ],
    );
  }
}
