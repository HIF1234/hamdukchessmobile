import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/active_game.dart';
import '../core/api.dart';
import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/home_widget_sync.dart';
import '../core/notifications_screen.dart';
import '../core/settings.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../bots/bot_game_screen.dart';
import '../engine/device.dart';
import '../local_play/local_tournament_home_screen.dart';
import '../profile/subscription_sheet.dart';
import '../puzzles/daily_puzzle_screen.dart';
import '../tournaments/tournaments_screen.dart';
import 'challenge_screens.dart';
import 'correspondence_screen.dart';
import 'game_history_screen.dart';
import 'game_screen.dart';
import 'game_state.dart';
import 'open_challenges_screen.dart';
import 'spectate_screen.dart';

String _categoryName(String category) => category.isEmpty
    ? ''
    : '${category[0].toUpperCase()}${category.substring(1)}';

/// Lets something outside PlayScreen (the "Play 5 min" icon shortcut) ask it to start
/// seeking -- PlayScreen is built once and kept alive by HomeShell's IndexedStack, so a
/// broadcast stream reaches it on every request, not just the first.
class PlayScreenActions {
  static final _seekController = StreamController<String>.broadcast();
  static Stream<String> get seekRequests => _seekController.stream;
  static void requestSeek(String timeControl) =>
      _seekController.add(timeControl);
}

/// "10+0" -> "10 min" for the Quick game headline.
String _quickGameLabel(String id) => '${id.split('+').first} min';

/// Pick a time control and find an opponent. Works like the website: ask the server every
/// few seconds, and also listen for our new game so pairing shows the moment it happens.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.config});
  final AppConfig config;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  static const _poll = Duration(seconds: 3);
  static const _giveUp = Duration(minutes: 2);

  String? _seeking; // time control id
  DateTime? _since;
  Timer? _timer;
  RealtimeChannel? _channel;
  String? _error;
  int _gamesPlayed = -1; // for the spec §10 cohort; -1 until known
  String _tier =
      'free'; // decides which bots are unlocked; cached for offline use
  bool _lowMemory = false;
  String _lastTimeControl =
      '10+0'; // Quick game defaults to 10+0 on first launch
  int _unread = 0;
  bool _rated = true; // quick-play rated/casual switch
  String _variant = 'standard'; // Chess960 switch, Plus members only
  int _ratingWindow = 50; // widens 50 -> 100 -> 200 -> 400 -> 1000 ("anyone") while waiting
  bool _botOffered = false; // "Play Agbero while you wait?" shown at most once per search
  int _elapsedSec = 0;
  Timer? _tick;
  Map<String, int> _looking = const {}; // live counts: time control -> players searching
  int _playingNow = 0;

  List<GameState>? _activeGames; // online games in progress, your-move first
  ActiveGame? _pendingBot; // a bot game left mid-way, if any
  Map<String, dynamic>? _dailyPuzzle;
  int _puzzleStreak = 0;
  List<Map<String, dynamic>> _onlineFriends = const [];
  Map<String, dynamic>? _joinedTournament; // the next one I'm in, if any
  StreamSubscription<String>? _seekRequests;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadLastTimeControl();
    _loadUnread();
    _loadContinue();
    _loadDaily();
    _loadFriendsOnline();
    _loadTournament();
    _loadLiveCounts();
    Device.isLowMemory()
        .then((v) {
          if (mounted) setState(() => _lowMemory = v);
        })
        .catchError((_) {});
    _seekRequests = PlayScreenActions.seekRequests.listen((tc) {
      if (_seeking == null) _seek(tc);
    });
  }

  /// Unfinished games for the continue card: online games in progress (from /games) plus a
  /// bot game left mid-way (tracked locally, since bot games never touch the server).
  Future<void> _loadContinue() async {
    final bot = await ActiveGame.peek();
    if (mounted) {
      setState(() => _pendingBot = bot is BotActiveGame ? bot : null);
    }
    try {
      final r = await Api.instance.get('/games') as Map<String, dynamic>;
      final active =
          (r['active'] as List)
              .cast<Map<String, dynamic>>()
              .map(GameState.fromApi)
              .toList()
            ..sort((a, b) {
              final aMine = a.whiteToMove == (a.white.id == _myId);
              final bMine = b.whiteToMove == (b.white.id == _myId);
              return aMine == bMine ? 0 : (aMine ? -1 : 1);
            });
      if (mounted) setState(() => _activeGames = active);
    } on ApiError {
      // Offline or failed: the card just shows the bot game, if any.
    }
  }

  Future<void> _loadDaily() async {
    try {
      final j = await Api.instance.get('/puzzles/daily');
      final me = await Api.instance.get('/me') as Map;
      final streak =
          ((me['puzzles'] as Map?)?['current_streak'] as num?)?.toInt() ?? 0;
      final puzzle = j as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _dailyPuzzle = puzzle;
          _puzzleStreak = streak;
        });
      }
      unawaited(
        syncHomeWidget(
          rating: (puzzle?['rating'] as num?)?.toInt(),
          streak: streak,
        ),
      );
    } catch (_) {
      // Offline or no puzzle today: the card just doesn't show.
    }
  }

  Future<void> _loadFriendsOnline() async {
    try {
      final r =
          await Api.instance.get('/social/friends') as Map<String, dynamic>;
      final accepted = (r['accepted'] as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(
          () => _onlineFriends = accepted
              .where((f) => f['online'] == true)
              .toList(),
        );
      }
    } catch (_) {
      // Offline or failed: the row just doesn't show.
    }
  }

  Future<void> _loadTournament() async {
    try {
      final r = await Api.instance.get('/tournaments') as Map<String, dynamic>;
      final rows = (r['tournaments'] as List).cast<Map<String, dynamic>>();
      final mine =
          rows
              .where((t) => t['joined'] == true && t['status'] != 'completed')
              .toList()
            ..sort(
              (a, b) => (a['starts_at'] as String? ?? '').compareTo(
                b['starts_at'] as String? ?? '',
              ),
            );
      if (mounted) {
        setState(() => _joinedTournament = mine.isEmpty ? null : mine.first);
      }
    } catch (_) {
      // Offline or failed: the section just doesn't show.
    }
  }

  /// "214 playing, 37 looking for 5 min" above the time-control tiles.
  Future<void> _loadLiveCounts() async {
    try {
      final r = await Api.instance.get('/stats/live') as Map<String, dynamic>;
      final looking = (r['looking'] as Map).cast<String, dynamic>();
      if (mounted) {
        setState(() {
          _playingNow = (r['playing'] as num?)?.toInt() ?? 0;
          _looking = looking.map((k, v) => MapEntry(k, (v as num).toInt()));
        });
      }
    } catch (_) {
      // Offline or failed: the line above the tiles just doesn't show.
    }
  }

  /// "Tunde challenges you to 5 min": a push notification, not a shared link -- the friend
  /// gets Accept/Decline (ChallengeAcceptScreen) and it expires in 10 minutes.
  Future<void> _challengeOnlineFriend(Map<String, dynamic> friend) async {
    try {
      final r = await Api.instance.post('/challenges', {
        'timeControl': _lastTimeControl,
        'color': 'random',
        'rated': false,
        'targetUserId': friend['userId'],
      }) as Map;
      final id = r['id'] as String;
      final url = r['url'] as String;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeWaitScreen(
            challengeId: id,
            url: url,
            timeControl: _lastTimeControl,
            targetUsername: friend['username'] as String?,
          ),
        ),
      );
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _loadUnread() async {
    try {
      final r = await Api.instance.get('/notifications') as Map;
      if (mounted) {
        setState(() => _unread = (r['unread'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {
      // Offline or failed: the bell just shows no count.
    }
  }

  Future<void> _loadLastTimeControl() async {
    final store = await JsonStore.open();
    final cached = await store.read('last_time_control');
    if (cached is String && mounted) setState(() => _lastTimeControl = cached);
  }

  Future<void> _loadMe() async {
    final store = await JsonStore.open();
    final cached = await store.read('me_tier');
    if (cached is String && mounted) setState(() => _tier = cached);
    try {
      final me = await Api.instance.get('/me') as Map;
      final ratings = (me['ratings'] as List).cast<Map>();
      _gamesPlayed = ratings.fold<int>(
        0,
        (n, r) => n + ((r['games_played'] as num?)?.toInt() ?? 0),
      );
      final tier = (me['account'] as Map)['tier'] as String? ?? 'free';
      await store.write('me_tier', tier);
      if (mounted) setState(() => _tier = tier);
    } catch (_) {
      // Offline or failed: keep the cached tier; events are logged without the game count.
    }
  }

  Future<void> _challengeFriend() async {
    final tcs = widget.config.timeControls;
    var tc =
        tcs.firstWhere((t) => t['id'] == '10+0', orElse: () => tcs.first)['id']
            as String;
    var colour = 'random';
    var rated = false;
    var variant = 'standard';
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Challenge a friend',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tcs)
                      ChoiceChip(
                        label: Text(t['id'] as String),
                        selected: tc == t['id'],
                        onSelected: (_) => set(() => tc = t['id'] as String),
                      ),
                    ActionChip(
                      label: const Text('Custom…'),
                      onPressed: () async {
                        final custom = await _pickCustomTimeControl(ctx);
                        if (custom != null) set(() => tc = custom);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'white', label: Text('White')),
                    ButtonSegment(value: 'random', label: Text('Random')),
                    ButtonSegment(value: 'black', label: Text('Black')),
                  ],
                  selected: {colour},
                  onSelectionChanged: (s) => set(() => colour = s.first),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rated'),
                  value: rated,
                  onChanged: (v) => set(() => rated = v),
                ),
                if (_tier != 'free')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chess960'),
                    value: variant == 'chess960',
                    onChanged: (v) => set(() => variant = v ? 'chess960' : 'standard'),
                  ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.share),
                  label: const Text('Create link and share'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (go == true && mounted) {
      await createAndShareChallenge(
        context,
        timeControl: tc,
        color: colour,
        rated: rated,
        variant: variant,
      );
    }
  }

  /// 1-60 minutes, 0-30 seconds a move -- posted as an open challenge (the custom time
  /// control isn't one quick play can match on, only a challenge link).
  Future<String?> _pickCustomTimeControl(BuildContext context) async {
    var minutes = 10;
    var seconds = 0;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Custom time control', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(children: [
                      Text('$minutes min'),
                      Slider(
                        value: minutes.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        onChanged: (v) => set(() => minutes = v.round()),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: Column(children: [
                      Text('+$seconds sec'),
                      Slider(
                        value: seconds.toDouble(),
                        min: 0,
                        max: 30,
                        divisions: 30,
                        onChanged: (v) => set(() => seconds = v.round()),
                      ),
                    ]),
                  ),
                ]),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, '$minutes+$seconds'),
                  child: const Text('Use this time control'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playBot(Map<String, dynamic> bot) async {
    var side = 'random';
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(HcSpace.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(HcRadius.md),
                        child: ColoredBox(
                          color: hcStageFor(bot['rating'] as num),
                          child: AppSettings.instance.lowData
                              ? Center(
                                  child: Text(
                                    hcInitials(bot['name'] as String),
                                    style: HcText.ratingXl.copyWith(
                                      color: HcColors.forest,
                                    ),
                                  ),
                                )
                              : Image.network(
                                  bot['portraitUrl'] as String,
                                  fit: BoxFit.cover,
                                  color: hcStageFor(bot['rating'] as num),
                                  colorBlendMode: BlendMode.multiply,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: HcSpace.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bot['name'] as String,
                            style: HcText.displayMd.copyWith(color: ctx.hc.ink),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: ctx.hc.ink2,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${bot['hometown']} · ${hcNumber((bot['rating'] as num).toInt())}',
                                  style: HcText.bodySm.copyWith(
                                    color: ctx.hc.ink2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HcSpace.s4),
                Text(
                  '“${bot['catchphrase']}”',
                  style: HcText.bodySm.copyWith(color: ctx.hc.ink3),
                ),
                const SizedBox(height: HcSpace.s5),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'w', label: Text('White')),
                    ButtonSegment(value: 'random', label: Text('Random')),
                    ButtonSegment(value: 'b', label: Text('Black')),
                  ],
                  selected: {side},
                  onSelectionChanged: (s) => set(() => side = s.first),
                ),
                const SizedBox(height: HcSpace.s4),
                PlayButton(
                  label: 'Play ${bot['name']}',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    final playWhite = side == 'random'
        ? DateTime.now().millisecond.isEven
        : side == 'w';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BotGameScreen(bot: bot, playWhite: playWhite),
      ),
    );
  }

  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  Future<void> _seek(String tc) async {
    setState(() {
      _seeking = tc;
      _since = DateTime.now();
      _error = null;
      _lastTimeControl = tc;
      _ratingWindow = 50;
      _botOffered = false;
      _elapsedSec = 0;
    });
    JsonStore.open().then((store) => store.write('last_time_control', tc));
    _listenForGame();
    await _ask();
    _timer = Timer.periodic(_poll, (_) async {
      if (DateTime.now().difference(_since!) > _giveUp) {
        await _cancel(message: 'No opponent found yet. Try again in a moment.');
      } else {
        // Widens as it waits: 50 -> 100 -> 200 -> 400 -> 1000 ("anyone").
        _ratingWindow = switch (_ratingWindow) {
          50 => 100,
          100 => 200,
          200 => 400,
          _ => 1000,
        };
        await _ask();
      }
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _seeking == null) return;
      setState(() => _elapsedSec++);
      if (_elapsedSec >= 30 && !_botOffered) {
        _botOffered = true;
        _offerBotWhileWaiting();
      }
    });
  }

  Future<void> _ask() async {
    final tc = _seeking;
    if (tc == null) return;
    try {
      final r = await Api.instance.post('/seek', {
        'timeControl': tc,
        'rated': _rated,
        'ratingWindow': _ratingWindow,
        'variant': _variant,
      }) as Map;
      final id = r['gameId'] as String?;
      if (id != null) _open(id);
    } on ApiError catch (e) {
      if (!e.isNetwork) await _cancel(message: e.message);
      // On a network blip keep waiting; the next poll tries again.
    }
  }

  /// "Nobody free at your level yet. Play Agbero while you wait?" -- the search carries on
  /// in the background and still opens the real game the moment one is found.
  Future<void> _offerBotWhileWaiting() async {
    final matches = widget.config.bots.where((b) => b['id'] == 'agbero');
    if (matches.isEmpty || !mounted) return;
    final play = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nobody free at your level yet.'),
        content: const Text('Play Agbero while you wait? We keep looking for a real opponent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep waiting')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Play Agbero')),
        ],
      ),
    );
    if (play == true && mounted) {
      final playWhite = DateTime.now().millisecond.isEven;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BotGameScreen(bot: matches.first, playWhite: playWhite),
      ));
    }
  }

  void _listenForGame() {
    final client = Supabase.instance.client;
    void onInsert(PostgresChangePayload p) =>
        _open(p.newRecord['id'] as String);
    _channel = client
        .channel('seek:$_myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'white_id',
            value: _myId,
          ),
          callback: onInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'black_id',
            value: _myId,
          ),
          callback: onInsert,
        )
        .subscribe();
  }

  Future<void> _stopWaiting() async {
    _timer?.cancel();
    _timer = null;
    _tick?.cancel();
    _tick = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) await Supabase.instance.client.removeChannel(ch);
  }

  Future<void> _cancel({String? message}) async {
    await _stopWaiting();
    try {
      await Api.instance.delete('/seek');
    } catch (_) {
      // The server also drops stale seeks on its own.
    }
    if (mounted) {
      setState(() {
        _seeking = null;
        _error = message;
      });
    }
  }

  Future<void> _open(String gameId) async {
    if (_seeking == null) return; // already opened
    await _stopWaiting();
    if (!mounted) return;
    setState(() => _seeking = null);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GameScreen(gameId: gameId, myId: _myId, gamesPlayed: _gamesPlayed),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick?.cancel();
    _seekRequests?.cancel();
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final tcs = widget.config.timeControls;
    final quickGame = tcs.firstWhere(
      (t) => t['id'] == _lastTimeControl,
      orElse: () =>
          tcs.firstWhere((t) => t['id'] == '10+0', orElse: () => tcs.first),
    );
    return RefreshIndicator(
      onRefresh: () => Future.wait([
        _loadMe(),
        _loadUnread(),
        _loadContinue(),
        _loadDaily(),
        _loadFriendsOnline(),
        _loadTournament(),
      ]),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            title: 'Play',
            subtitle: 'Find an opponent or train against a bot',
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        )
                        .then((_) => _loadUnread()),
                  ),
                  if (_unread > 0)
                    Positioned(top: 6, right: 6, child: HcBadge.count(_unread)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GameHistoryScreen()),
                ),
              ),
            ],
          ),
          if (AppSettings.instance.lowData)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HcSpace.s4,
                0,
                HcSpace.s4,
                HcSpace.s2,
              ),
              child: Text(
                '${DataMeter.label} this session',
                style: HcText.bodySm.copyWith(color: hc.ink3),
              ),
            ),
          _ContinueCard(
            games: _activeGames,
            pendingBot: _pendingBot,
            myId: _myId,
            config: widget.config,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HcSpace.s4,
              0,
              HcSpace.s4,
              HcSpace.s4,
            ),
            child: HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: HeroCard.overline('Quick game')),
                    GestureDetector(
                      onTap: _seeking == null ? () => setState(() => _rated = !_rated) : null,
                      child: HcBadge.onHero(_rated ? 'Rated' : 'Casual'),
                    ),
                  ]),
                  const SizedBox(height: HcSpace.s1),
                  Text(
                    _quickGameLabel(quickGame['id'] as String),
                    style: HcText.displayXl.copyWith(color: HcColors.onForest),
                  ),
                  const SizedBox(height: 2),
                  HeroCard.sub(
                    _seeking == quickGame['id']
                        ? 'Searching… ${_elapsedSec}s · within $_ratingWindow rating points'
                        : '${_categoryName(quickGame['category'] as String)} · ${_rated ? 'rated' : 'casual'} · your last time control',
                  ),
                  const SizedBox(height: HcSpace.s4),
                  PlayButton(
                    label: 'Play',
                    onPressed: _seeking == null
                        ? () => _seek(quickGame['id'] as String)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (_playingNow > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(HcSpace.s4, 0, HcSpace.s4, HcSpace.s2),
              child: Text(
                '$_playingNow playing${_looking[_lastTimeControl] != null ? ', ${_looking[_lastTimeControl]} looking for ${_quickGameLabel(_lastTimeControl)}' : ''}',
                style: HcText.bodySm.copyWith(color: hc.ink3),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Time controls'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HcSpace.s2),
                    child: HcBanner(
                      icon: Icons.error_outline_rounded,
                      text: _error!,
                      tone: HcBannerTone.error,
                    ),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisExtent: HcSize.tcTile,
                    crossAxisSpacing: HcSpace.s2,
                    mainAxisSpacing: HcSpace.s2,
                  ),
                  itemCount: tcs.length,
                  itemBuilder: (context, i) {
                    final tc = tcs[i];
                    final id = tc['id'] as String;
                    return TimeControlTile(
                      id: id,
                      category: tc['category'] as String,
                      searching: _seeking == id,
                      dimmed: _seeking != null && _seeking != id,
                      onTap: _seeking == null ? () => _seek(id) : null,
                    );
                  },
                ),
                if (_tier != 'free') ...[
                  const SizedBox(height: HcSpace.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Chess960'),
                      selected: _variant == 'chess960',
                      onSelected: _seeking == null
                          ? (v) => setState(() => _variant = v ? 'chess960' : 'standard')
                          : null,
                    ),
                  ),
                ],
                if (_seeking != null) ...[
                  const SizedBox(height: HcSpace.s2),
                  Center(
                    child: TextButton(
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
                const SizedBox(height: HcSpace.s4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _seeking == null ? _challengeFriend : null,
                        icon: const Icon(Icons.person_add_rounded, size: 20),
                        label: const Text('Play a friend'),
                      ),
                    ),
                    const SizedBox(width: HcSpace.s3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SpectateScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_rounded, size: 20),
                        label: const Text('Watch live'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HcSpace.s3),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OpenChallengesScreen()),
                        ),
                        icon: const Icon(Icons.public_rounded, size: 20),
                        label: const Text('Open challenges'),
                      ),
                    ),
                    const SizedBox(width: HcSpace.s3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CorrespondenceScreen()),
                        ),
                        icon: const Icon(Icons.calendar_today_rounded, size: 20),
                        label: const Text('Daily games'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HcSpace.s7),
                if (_dailyPuzzle != null) ...[
                  _DailyPuzzleCard(
                    puzzle: _dailyPuzzle!,
                    streak: _puzzleStreak,
                  ),
                  const SizedBox(height: HcSpace.s7),
                ],
                if (_onlineFriends.isNotEmpty) ...[
                  const SectionLabel('Friends online'),
                  const SizedBox(height: HcSpace.s2),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _onlineFriends.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(width: HcSpace.s3),
                      itemBuilder: (context, i) {
                        final f = _onlineFriends[i];
                        return _OnlineFriendTile(
                          friend: f,
                          onTap: () => _challengeOnlineFriend(f),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: HcSpace.s7),
                ],
                if (_joinedTournament != null) ...[
                  const SectionLabel('Your tournament'),
                  const SizedBox(height: HcSpace.s2),
                  FeaturedTournamentHero(row: _joinedTournament!),
                  const SizedBox(height: HcSpace.s3),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TournamentsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.emoji_events_outlined, size: 20),
                        label: const Text('All tournaments'),
                      ),
                    ),
                    const SizedBox(width: HcSpace.s3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LocalTournamentHomeScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.wifi_tethering_rounded,
                          size: 20,
                        ),
                        label: const Text('Host local'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HcSpace.s7),
                const SectionLabel('Naija bots'),
                Text(
                  "Play offline, no data needed. Bot games don't change your rating.",
                  style: HcText.bodySm.copyWith(color: hc.ink2),
                ),
                if (_lowMemory)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'The strongest bots are hidden on this phone to keep it smooth.',
                      style: HcText.bodySm.copyWith(color: hc.ink2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: HcSpace.s3),
          SizedBox(
            height: 290,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
              children: [
                for (final b in widget.config.bots)
                  // The 2400+ bots search deepest; skip them on phones under 3 GB for now (spec §3).
                  if (!(_lowMemory && (b['rating'] as num) >= 2400))
                    Padding(
                      padding: const EdgeInsets.only(right: HcSpace.s3),
                      child: PersonaCard(
                        name: b['name'] as String,
                        hometown: b['hometown'] as String,
                        rating: (b['rating'] as num).toInt(),
                        catchphrase: b['catchphrase'] as String,
                        portraitUrl: b['portraitUrl'] as String?,
                        locked: b['tier'] == 'plus' && _tier == 'free',
                        lowData: AppSettings.instance.lowData,
                        onTap: b['tier'] == 'plus' && _tier == 'free'
                            ? () => showSubscriptionSheet(context, _tier)
                            : () => _playBot(b),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: HcSpace.s4),
        ],
      ),
    );
  }
}

/// Unfinished games, your-move ones first: online games in progress plus a bot game left
/// mid-way (bot games never reach the server, so that one comes from ActiveGame instead).
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.games,
    required this.pendingBot,
    required this.myId,
    required this.config,
  });
  final List<GameState>? games;
  final ActiveGame? pendingBot;
  final String myId;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final online = games ?? const [];
    final bot = pendingBot;
    if (online.isEmpty && bot is! BotActiveGame) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(HcSpace.s4, 0, HcSpace.s4, HcSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Continue'),
          const SizedBox(height: HcSpace.s2),
          HcListGroup(
            children: [
              for (final g in online) _ContinueGameRow(game: g, myId: myId),
              if (bot is BotActiveGame)
                _ContinueBotRow(bot: bot, config: config),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinueGameRow extends StatelessWidget {
  const _ContinueGameRow({required this.game, required this.myId});
  final GameState game;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final isWhite = game.white.id == myId;
    final opponent = isWhite ? game.black : game.white;
    final yourMove = game.whiteToMove == isWhite;
    return HcListRow(
      leading: HcAvatar(name: opponent.username, size: HcSize.avatarMd),
      title: 'vs ${opponent.username}',
      subtitle:
          '${yourMove ? 'Your move' : "Opponent's move"} · ${game.timeControl}',
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(gameId: game.id, myId: myId),
        ),
      ),
    );
  }
}

class _ContinueBotRow extends StatelessWidget {
  const _ContinueBotRow({required this.bot, required this.config});
  final BotActiveGame bot;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final matches = config.bots.where((b) => b['id'] == bot.botId);
    if (matches.isEmpty) return const SizedBox.shrink();
    final persona = matches.first;
    return HcListRow(
      leading: HcAvatar(name: persona['name'] as String, size: HcSize.avatarMd),
      title: 'vs ${persona['name']}',
      subtitle: 'Your move · bot game',
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BotGameScreen(
            bot: persona,
            playWhite: bot.playWhite,
            initialSanMoves: bot.sanMoves,
          ),
        ),
      ),
    );
  }
}

/// Today's puzzle and the streak, one tap to solve.
class _DailyPuzzleCard extends StatelessWidget {
  const _DailyPuzzleCard({required this.puzzle, required this.streak});
  final Map<String, dynamic> puzzle;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return InkWell(
      borderRadius: BorderRadius.circular(HcRadius.md),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DailyPuzzleScreen())),
      child: Container(
        padding: const EdgeInsets.all(HcSpace.s4),
        decoration: BoxDecoration(
          color: hc.greenSoft,
          borderRadius: BorderRadius.circular(HcRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.extension_rounded, color: hc.green, size: 28),
            const SizedBox(width: HcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily puzzle',
                    style: HcText.titleMd.copyWith(color: hc.ink),
                  ),
                  Text(
                    'Rated ${puzzle['rating']} · one tap to solve',
                    style: HcText.bodySm.copyWith(color: hc.ink2),
                  ),
                ],
              ),
            ),
            if (streak > 0) HcBadge.streak(streak),
          ],
        ),
      ),
    );
  }
}

class _OnlineFriendTile extends StatelessWidget {
  const _OnlineFriendTile({required this.friend, required this.onTap});
  final Map<String, dynamic> friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return InkWell(
      borderRadius: BorderRadius.circular(HcRadius.md),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HcAvatar(
              name: friend['username'] as String? ?? '?',
              size: HcSize.avatarMd,
              online: true,
            ),
            const SizedBox(height: 4),
            Text(
              friend['username'] as String? ?? '',
              style: HcText.bodySm.copyWith(color: hc.ink2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
