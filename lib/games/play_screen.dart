import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/app_config.dart';
import '../core/settings.dart';
import '../core/storage.dart';
import '../bots/bot_game_screen.dart';
import '../engine/device.dart';
import 'challenge_screens.dart';
import 'game_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMe();
    Device.isLowMemory().then((v) {
      if (mounted) setState(() => _lowMemory = v);
    }).catchError((_) {});
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
    final side = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('Play ${bot['name']} as…')),
          ListTile(title: const Text('White'), onTap: () => Navigator.pop(ctx, 'w')),
          ListTile(title: const Text('Black'), onTap: () => Navigator.pop(ctx, 'b')),
          ListTile(title: const Text('Random'), onTap: () => Navigator.pop(ctx, DateTime.now().millisecond.isEven ? 'w' : 'b')),
        ]),
      ),
    );
    if (side == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BotGameScreen(bot: bot, playWhite: side == 'w'),
    ));
  }

  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  Future<void> _seek(String tc) async {
    setState(() {
      _seeking = tc;
      _since = DateTime.now();
      _error = null;
    });
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
    final t = Theme.of(context);
    final tcs = widget.config.timeControls;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Play online', style: t.textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (_seeking != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text('Finding a $_seeking opponent…')),
                TextButton(onPressed: () => _cancel(), child: const Text('Cancel')),
              ]),
            ),
          )
        else ...[
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!)),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              for (final tc in tcs)
                OutlinedButton(
                  onPressed: () => _seek(tc['id'] as String),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(tc['id'] as String, style: t.textTheme.titleMedium),
                    Text(tc['category'] as String, style: t.textTheme.bodySmall),
                  ]),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _seeking == null ? _challengeFriend : null,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Challenge a friend (WhatsApp link)'),
        ),
        const SizedBox(height: 24),
        Text('Naija bots', style: t.textTheme.titleMedium),
        const Text('Play offline, no data needed. Bot games don\'t change your rating.'),
        if (_lowMemory)
          Text('The strongest bots are hidden on this phone to keep it smooth.', style: t.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final b in widget.config.bots)
          // The 2400+ bots search deepest; skip them on phones under 3 GB for now (spec §3).
          if (!(_lowMemory && (b['rating'] as num) >= 2400))
          ListTile(
            onTap: b['tier'] == 'plus' && _tier == 'free'
                ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('This bot is part of Hamduk Plus. Upgrade at play.chess.hamduk.com.ng/billing.')))
                : () => _playBot(b),
            contentPadding: EdgeInsets.zero,
            // Low data mode skips the portraits (about 30 KB each).
            leading: AppSettings.instance.lowData
                ? CircleAvatar(child: Text((b['name'] as String).substring(0, 1)))
                : CircleAvatar(backgroundImage: NetworkImage(b['portraitUrl'] as String)),
            title: Text(b['name'] as String),
            subtitle: Text('${b['hometown']} · ${b['catchphrase']}'),
            trailing: b['tier'] == 'plus' && _tier == 'free'
                ? const Icon(Icons.lock_outline)
                : Text('${b['rating']}'),
          ),
      ],
    );
  }
}
