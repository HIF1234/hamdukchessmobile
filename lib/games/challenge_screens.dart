import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import 'game_screen.dart';

String get _myId => Supabase.instance.client.auth.currentUser!.id;

Future<void> _openGame(BuildContext context, String gameId) => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(gameId: gameId, myId: _myId)),
    );

/// Creates a challenge and hands the link to the share sheet (WhatsApp and the rest).
Future<void> createAndShareChallenge(
  BuildContext context, {
  required String timeControl,
  required String color,
  required bool rated,
  String variant = 'standard',
}) async {
  try {
    final r = await Api.instance.post('/challenges', {
      'timeControl': timeControl,
      'color': color,
      'rated': rated,
      'variant': variant,
    }) as Map;
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

/// [expiresInHours] is omitted for a targeted in-app challenge's own share text (it's sent
/// as a push instead), and included for a shared link, where the recipient may not open it
/// right away.
String shareText(String timeControl, String url, {int? expiresInHours}) {
  final expiry = expiresInHours == null ? '' : ' (expires in ${expiresInHours}h)';
  return 'I challenge you to a $timeControl game of chess on Hamduk Chess!$expiry Tap to accept: $url';
}

/// The sender waits here for a friend to accept. Opens the game the moment they do (live
/// update, with a slower check as a backup in case the live connection drops).
class ChallengeWaitScreen extends StatefulWidget {
  const ChallengeWaitScreen({super.key, required this.challengeId, required this.url, required this.timeControl, this.targetUsername});
  final String challengeId;
  final String url;
  final String timeControl;

  /// Set for a friend targeted directly (not a link): they already got a push, so this
  /// skips the share sheet and names them instead of saying "your friend".
  final String? targetUsername;

  @override
  State<ChallengeWaitScreen> createState() => _ChallengeWaitScreenState();
}

class _ChallengeWaitScreenState extends State<ChallengeWaitScreen> {
  RealtimeChannel? _channel;
  Timer? _poll;
  bool _opened = false;
  bool _declined = false;

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
          callback: (p) => _onUpdate(p.newRecord),
        )
        .subscribe();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
    if (widget.targetUsername == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _share());
    }
  }

  Future<void> _check() async {
    try {
      final c = await Api.instance.get('/challenges/${widget.challengeId}') as Map;
      _onUpdate(c.cast<String, dynamic>());
    } catch (_) {
      // offline for a moment; the next check tries again
    }
  }

  void _onUpdate(Map<String, dynamic> row) {
    final gameId = row['game_id'] as String?;
    if (gameId != null) {
      _maybeOpen(gameId);
      return;
    }
    if (row['declined'] == true && mounted) setState(() => _declined = true);
  }

  void _maybeOpen(String? gameId) {
    if (gameId == null || _opened || !mounted) return;
    _opened = true;
    _openGame(context, gameId);
  }

  Future<void> _share() => SharePlus.instance
      .share(ShareParams(text: shareText(widget.timeControl, widget.url, expiresInHours: 24)));

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
            if (_declined) ...[
              const Icon(Icons.close_rounded, size: 48),
              const SizedBox(height: 16),
              Text('${widget.targetUsername ?? 'Your friend'} declined.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
            ] else ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                'Waiting for ${widget.targetUsername ?? 'your friend'} to accept your ${widget.timeControl} challenge…',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.targetUsername == null
                    ? 'The game opens here as soon as they tap your link.'
                    : 'They have 10 minutes to accept. The game opens here the moment they do.',
                textAlign: TextAlign.center,
              ),
              if (widget.targetUsername == null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Share the link again')),
                const SizedBox(height: 24),
                const Text('Or show this to someone in the same room:', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Center(child: QrImageView(data: widget.url, size: 180)),
              ],
            ],
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

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await Api.instance.post('/challenges/${widget.challengeId}/decline');
      if (mounted) Navigator.of(context).pop();
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
    } else if (c['declined'] == true) {
      body = const Text('You already declined this challenge.', textAlign: TextAlign.center);
    } else if (c['target_user_id'] != null && c['target_user_id'] != _myId) {
      body = const Text('This challenge was sent to someone else.', textAlign: TextAlign.center);
    } else {
      final creator = (c['creator'] as Map?)?['username'] ?? 'A player';
      final colour = switch (c['creator_color']) { 'white' => 'You play Black', 'black' => 'You play White', _ => 'Colours are random' };
      final targeted = c['target_user_id'] != null;
      body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$creator challenges you!', style: t.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${c['time_control']} · ${c['rated'] == true ? 'Rated' : 'Casual'} · $colour', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy ? null : _accept, child: Text(_busy ? 'Starting…' : 'Accept and play')),
        if (targeted) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _decline, child: const Text('Decline')),
        ],
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: body)),
    );
  }
}
