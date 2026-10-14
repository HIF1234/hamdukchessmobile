import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/notifications_screen.dart';
import '../core/settings.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../bots/bot_game_screen.dart';
import '../engine/device.dart';
import '../profile/subscription_sheet.dart';
import 'challenge_screens.dart';
import 'game_history_screen.dart';
import 'game_screen.dart';
import 'spectate_screen.dart';

String _categoryName(String category) => category.isEmpty ? '' : '${category[0].toUpperCase()}${category.substring(1)}';

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
  String _tier = 'free'; // decides which bots are unlocked; cached for offline use
  bool _lowMemory = false;
  String _lastTimeControl = '10+0'; // Quick game defaults to 10+0 on first launch
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadLastTimeControl();
    _loadUnread();
    Device.isLowMemory().then((v) {
      if (mounted) setState(() => _lowMemory = v);
    }).catchError((_) {});
  }

  Future<void> _loadUnread() async {
    try {
      final r = await Api.instance.get('/notifications') as Map;
      if (mounted) setState(() => _unread = (r['unread'] as num?)?.toInt() ?? 0);
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
      _gamesPlayed = ratings.fold<int>(0, (n, r) => n + ((r['games_played'] as num?)?.toInt() ?? 0));
      final tier = (me['account'] as Map)['tier'] as String? ?? 'free';
      await store.write('me_tier', tier);
      if (mounted) setState(() => _tier = tier);
    } catch (_) {
      // Offline or failed: keep the cached tier; events are logged without the game count.
    }
  }

  Future<void> _challengeFriend() async {
    final tcs = widget.config.timeControls;
    var tc = tcs.firstWhere((t) => t['id'] == '10+0', orElse: () => tcs.first)['id'] as String;
    var colour = 'random';
    var rated = false;
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Challenge a friend', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in tcs)
                  ChoiceChip(label: Text(t['id'] as String), selected: tc == t['id'], onSelected: (_) => set(() => tc = t['id'] as String)),
              ]),
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
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.share),
                label: const Text('Create link and share'),
              ),
            ]),
          ),
        ),
      ),
    );
    if (go == true && mounted) await createAndShareChallenge(context, timeControl: tc, color: colour, rated: rated);
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
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(HcRadius.md),
                    child: ColoredBox(
                      color: hcStageFor(bot['rating'] as num),
                      child: AppSettings.instance.lowData
                          ? Center(child: Text(hcInitials(bot['name'] as String), style: HcText.ratingXl.copyWith(color: HcColors.forest)))
                          : Image.network(bot['portraitUrl'] as String, fit: BoxFit.cover, color: hcStageFor(bot['rating'] as num),
                              colorBlendMode: BlendMode.multiply),
                    ),
                  ),
                ),
                const SizedBox(width: HcSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bot['name'] as String, style: HcText.displayMd.copyWith(color: ctx.hc.ink)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.location_on_outlined, size: 14, color: ctx.hc.ink2),
                        const SizedBox(width: 2),
                        Expanded(
                            child: Text('${bot['hometown']} · ${hcNumber((bot['rating'] as num).toInt())}',
                                style: HcText.bodySm.copyWith(color: ctx.hc.ink2), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: HcSpace.s4),
              Text('“${bot['catchphrase']}”', style: HcText.bodySm.copyWith(color: ctx.hc.ink3)),
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
              PlayButton(label: 'Play ${bot['name']}', onPressed: () => Navigator.pop(ctx, true)),
            ]),
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    final playWhite = side == 'random' ? DateTime.now().millisecond.isEven : side == 'w';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BotGameScreen(bot: bot, playWhite: playWhite),
    ));
  }

  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  Future<void> _seek(String tc) async {
    setState(() {
      _seeking = tc;
      _since = DateTime.now();
      _error = null;
      _lastTimeControl = tc;
    });
    JsonStore.open().then((store) => store.write('last_time_control', tc));
    _listenForGame();
    await _ask();
    _timer = Timer.periodic(_poll, (_) async {
      if (DateTime.now().difference(_since!) > _giveUp) {
        await _cancel(message: 'No opponent found yet. Try again in a moment.');
      } else {
        await _ask();
      }
    });
  }

  Future<void> _ask() async {
    final tc = _seeking;
    if (tc == null) return;
    try {
      final r = await Api.instance.post('/seek', {'timeControl': tc}) as Map;
      final id = r['gameId'] as String?;
      if (id != null) _open(id);
    } on ApiError catch (e) {
      if (!e.isNetwork) await _cancel(message: e.message);
      // On a network blip keep waiting; the next poll tries again.
    }
  }

  void _listenForGame() {
    final client = Supabase.instance.client;
    void onInsert(PostgresChangePayload p) => _open(p.newRecord['id'] as String);
    _channel = client
        .channel('seek:$_myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'white_id', value: _myId),
          callback: onInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'black_id', value: _myId),
          callback: onInsert,
        )
        .subscribe();
  }

  Future<void> _stopWaiting() async {
    _timer?.cancel();
    _timer = null;
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
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(gameId: gameId, myId: _myId, gamesPlayed: _gamesPlayed),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final tcs = widget.config.timeControls;
    final quickGame = tcs.firstWhere((t) => t['id'] == _lastTimeControl, orElse: () => tcs.firstWhere((t) => t['id'] == '10+0', orElse: () => tcs.first));
    return ListView(
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
                      .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))
                      .then((_) => _loadUnread()),
                ),
                if (_unread > 0) Positioned(top: 6, right: 6, child: HcBadge.count(_unread)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameHistoryScreen())),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(HcSpace.s4, 0, HcSpace.s4, HcSpace.s4),
          child: HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroCard.overline('Quick game'),
                const SizedBox(height: HcSpace.s1),
                Text(_quickGameLabel(quickGame['id'] as String), style: HcText.displayXl.copyWith(color: HcColors.onForest)),
                const SizedBox(height: 2),
                HeroCard.sub('${_categoryName(quickGame['category'] as String)} · rated · your last time control'),
                const SizedBox(height: HcSpace.s4),
                PlayButton(label: 'Play', onPressed: _seeking == null ? () => _seek(quickGame['id'] as String) : null),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Time controls'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: HcSpace.s2),
                child: HcBanner(icon: Icons.error_outline_rounded, text: _error!, tone: HcBannerTone.error),
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
            if (_seeking != null) ...[
              const SizedBox(height: HcSpace.s2),
              Center(child: TextButton(onPressed: _cancel, child: const Text('Cancel'))),
            ],
            const SizedBox(height: HcSpace.s4),
            Row(children: [
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
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpectateScreen())),
                  icon: const Icon(Icons.visibility_rounded, size: 20),
                  label: const Text('Watch live'),
                ),
              ),
            ]),
            const SizedBox(height: HcSpace.s7),
            const SectionLabel('Naija bots'),
            Text(
              "Play offline, no data needed. Bot games don't change your rating.",
              style: HcText.bodySm.copyWith(color: hc.ink2),
            ),
            if (_lowMemory)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('The strongest bots are hidden on this phone to keep it smooth.', style: HcText.bodySm.copyWith(color: hc.ink2)),
              ),
          ]),
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
                      onTap: b['tier'] == 'plus' && _tier == 'free' ? () => showSubscriptionSheet(context, _tier) : () => _playBot(b),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: HcSpace.s4),
      ],
    );
  }
}
