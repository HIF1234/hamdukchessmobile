import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import 'game_screen.dart';

String get _myId => Supabase.instance.client.auth.currentUser!.id;

Future<void> _openGame(BuildContext context, String gameId) => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(gameId: gameId, myId: _myId)),
    );

/// Creates a challenge and hands the link to the share sheet (WhatsApp and the rest).
Future<void> createAndShareChallenge(BuildContext context, {required String timeControl, required String color, required bool rated}) async {
  try {
    final r = await Api.instance.post('/challenges', {'timeControl': timeControl, 'color': color, 'rated': rated}) as Map;
    final id = r['id'] as String;
    final url = r['url'] as String;
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChallengeWaitScreen(challengeId: id, url: url, timeControl: timeControl),
    ));
  } on ApiError catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

String shareText(String timeControl, String url) =>
    "I challenge you to a $timeControl game of chess on Hamduk Chess! Tap to accept: $url";

/// The sender waits here for a friend to accept. Opens the game the moment they do (live
/// update, with a slower check as a backup in case the live connection drops).
class ChallengeWaitScreen extends StatefulWidget {
  const ChallengeWaitScreen({super.key, required this.challengeId, required this.url, required this.timeControl});
  final String challengeId;
  final String url;
  final String timeControl;

  @override
  State<ChallengeWaitScreen> createState() => _ChallengeWaitScreenState();
}

class _ChallengeWaitScreenState extends State<ChallengeWaitScreen> {
  RealtimeChannel? _channel;
  Timer? _poll;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client
        .channel('challenge:${widget.challengeId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_challenges',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.challengeId),
          callback: (p) => _maybeOpen(p.newRecord['game_id'] as String?),
        )
        .subscribe();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _share());
  }

  Future<void> _check() async {
    try {
      final c = await Api.instance.get('/challenges/${widget.challengeId}') as Map;
      _maybeOpen(c['game_id'] as String?);
    } catch (_) {
      // offline for a moment; the next check tries again
    }
  }

  void _maybeOpen(String? gameId) {
    if (gameId == null || _opened || !mounted) return;
    _opened = true;
    _openGame(context, gameId);
  }

  Future<void> _share() => SharePlus.instance.share(ShareParams(text: shareText(widget.timeControl, widget.url)));

  @override
  void dispose() {
    _poll?.cancel();
    final ch = _channel;
    if (ch != null) Supabase.instance.client.removeChannel(ch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Challenge a friend')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text('Waiting for your friend to accept your ${widget.timeControl} challenge…', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('The game opens here as soon as they tap your link.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Share the link again')),
          ]),
        ),
      );
}

/// Opened from a challenge link. Shows who sent it and lets the player accept.
class ChallengeAcceptScreen extends StatefulWidget {
  const ChallengeAcceptScreen({super.key, required this.challengeId});
  final String challengeId;

  @override
  State<ChallengeAcceptScreen> createState() => _ChallengeAcceptScreenState();
}

class _ChallengeAcceptScreenState extends State<ChallengeAcceptScreen> {
  Map<String, dynamic>? _c;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = (await Api.instance.get('/challenges/${widget.challengeId}') as Map).cast<String, dynamic>();
      if (!mounted) return;
      final gameId = c['game_id'] as String?;
      // Already accepted by this player (or it's their own and it's under way): go to the game.
      if (gameId != null && (c['mine'] == true || c['accepted_by'] == _myId)) {
        await _openGame(context, gameId);
        return;
      }
      setState(() => _c = c);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('/challenges/${widget.challengeId}/accept') as Map;
      if (mounted) await _openGame(context, r['gameId'] as String);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = _c;
    Widget body;
    if (_error != null) {
      body = Text(_error!, textAlign: TextAlign.center);
    } else if (c == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (c['mine'] == true) {
      body = const Text("This is your own challenge. Send the link to a friend so they can accept it.", textAlign: TextAlign.center);
    } else if (c['expired'] == true) {
      body = const Text('This challenge has expired. Ask your friend to send a new one.', textAlign: TextAlign.center);
    } else if (c['game_id'] != null) {
      body = const Text('Someone else already accepted this challenge.', textAlign: TextAlign.center);
    } else {
      final creator = (c['creator'] as Map?)?['username'] ?? 'A player';
      final colour = switch (c['creator_color']) { 'white' => 'You play Black', 'black' => 'You play White', _ => 'Colours are random' };
      body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$creator challenges you!', style: t.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${c['time_control']} · ${c['rated'] == true ? 'Rated' : 'Casual'} · $colour', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy ? null : _accept, child: Text(_busy ? 'Starting…' : 'Accept and play')),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: body)),
    );
  }
}
