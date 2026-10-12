import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui.dart';
import 'local_game_screen.dart';
import 'local_network.dart';

/// Scans the host's QR code (their local IP), connects over the hotspot's LAN, then shows a
/// lobby that pushes into a [LocalGameScreen] whenever the host pairs this player for a game.
class JoinLocalTournamentScreen extends StatefulWidget {
  const JoinLocalTournamentScreen({super.key});

  @override
  State<JoinLocalTournamentScreen> createState() => _JoinLocalTournamentScreenState();
}

class _JoinLocalTournamentScreenState extends State<JoinLocalTournamentScreen> {
  final _client = LocalTournamentClient();
  StreamSubscription<LocalMessage>? _sub;
  bool _scanned = false;
  bool _connecting = false;
  String? _error;
  List<Map<String, dynamic>> _lobby = [];
  List<Map<String, dynamic>> _standings = [];

  String get _username => Supabase.instance.client.auth.currentUser?.userMetadata?['username'] as String? ??
      Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
      'Player';

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final ip = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (ip == null) return;
    setState(() {
      _scanned = true;
      _connecting = true;
      _error = null;
    });
    final ok = await _client.connect(ip, _username);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _connecting = false;
        _scanned = false;
        _error = "Couldn't connect. Make sure you've joined the host's WiFi hotspot first.";
      });
      return;
    }
    setState(() => _connecting = false);
    _sub = _client.messages.listen(_onMessage);
  }

  void _onMessage(LocalMessage msg) {
    switch (msg['type']) {
      case 'lobby':
        if (mounted) setState(() => _lobby = (msg['players'] as List).cast<Map<String, dynamic>>());
      case 'standings':
        if (mounted) setState(() => _standings = (msg['rows'] as List).cast<Map<String, dynamic>>());
      case 'pairing':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LocalGameScreen(
            gameId: msg['gameId'] as String,
            playWhite: msg['color'] == 'white',
            opponentName: msg['opponent'] as String? ?? 'Opponent',
            fen: msg['fen'] as String? ?? kStartFen,
            messages: _client.messages,
            sendMove: (uci) => _client.send({'type': 'move', 'gameId': msg['gameId'], 'uci': uci}),
            sendResult: (result) => _client.send({'type': 'result', 'gameId': msg['gameId'], 'result': result}),
          ),
        ));
      case 'disconnected':
        if (mounted) setState(() => _error = 'Lost connection to the host.');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Join local tournament')),
      body: !_scanned
          ? Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Join the host\'s WiFi hotspot in your phone settings first, then scan their QR code below.',
                  style: t.textTheme.bodyMedium,
                ),
              ),
              Expanded(child: MobileScanner(onDetect: _onDetect)),
            ])
          : _connecting
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _scanned = false;
                              _error = null;
                            }),
                            child: const Text('Try again'),
                          ),
                        ]),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text("You're in! Waiting for the host to start a round…", style: t.textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        SectionLabel('Players (${_lobby.length})', icon: Icons.people_outline),
                        for (final p in _lobby) ListTile(dense: true, leading: const Icon(Icons.person_outline), title: Text(p['username'] as String)),
                        if (_standings.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const SectionLabel('Standings', icon: Icons.leaderboard_outlined),
                          for (var i = 0; i < _standings.length; i++)
                            ListTile(
                              dense: true,
                              leading: SizedBox(width: 24, child: Text('${i + 1}', textAlign: TextAlign.center)),
                              title: Text(_standings[i]['username'] as String),
                              trailing: Text('${_standings[i]['points']}'),
                            ),
                        ],
                      ],
                    ),
    );
  }
}
