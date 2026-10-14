import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'local_network.dart';
import 'pairing.dart';

/// Hosts a casual, data-free local tournament on this phone's hotspot. The host organizes
/// (pairs rounds, tracks standings) and does not play -- see the module doc on
/// local_network.dart for why. Results never touch the server.
class HostLocalTournamentScreen extends StatefulWidget {
  const HostLocalTournamentScreen({super.key});

  @override
  State<HostLocalTournamentScreen> createState() => _HostLocalTournamentScreenState();
}

class _HostLocalTournamentScreenState extends State<HostLocalTournamentScreen> {
  final _host = LocalTournamentHost();
  String? _ip;
  String? _error;
  List<LocalPlayer> _lobby = [];
  final _standings = <String, LocalStanding>{};
  int _round = 0;
  // Active pairings this round, keyed by the gameId the host assigned when starting them --
  // needed so a finished game's result (reported by gameId) can be matched back to remove it.
  final _activePairings = <String, Pairing>{};
  StreamSubscription? _lobbySub;
  StreamSubscription? _resultsSub;
  String _timeControl = '5+0';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ip = await _host.start();
    if (!mounted) return;
    if (ip == null) {
      setState(() => _error = "Couldn't find a WiFi network. Turn on your phone's hotspot first, then try again.");
      return;
    }
    setState(() => _ip = ip);
    _lobbySub = _host.lobby.listen((players) {
      if (!mounted) return;
      setState(() {
        _lobby = players;
        for (final p in players) {
          _standings.putIfAbsent(p.id, () => LocalStanding(p.id, p.username));
        }
      });
    });
    _resultsSub = _host.results.listen((r) {
      final (gameId, whiteId, blackId, result) = r;
      setState(() {
        applyResult(_standings, whiteId, blackId, result);
        _activePairings.remove(gameId);
      });
    });
  }

  void _startRound() {
    final standings = _standings.values.toList();
    final pairings = pairRound(standings);
    setState(() {
      _round++;
      _activePairings.clear();
    });
    for (final p in pairings) {
      if (p.blackId == null) {
        // A bye: credit the point immediately, nothing to pair.
        applyResult(_standings, p.whiteId, null, 'bye');
        continue;
      }
      final gameId = _host.startGame(p.whiteId, p.blackId!, timeControl: _timeControl);
      setState(() => _activePairings[gameId] = p);
    }
  }

  @override
  void dispose() {
    _lobbySub?.cancel();
    _resultsSub?.cancel();
    _host.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hc = context.hc;
    final sorted = _standings.values.toList()..sort((a, b) => b.points.compareTo(a.points));
    return Scaffold(
      appBar: AppBar(title: const Text('Host local tournament')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _ip == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Other players: turn on WiFi, join this phone\'s hotspot, then scan this code in '
                      '"Join local tournament" on their own phone. No mobile data needed for anyone.',
                      style: t.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: QrImageView(data: _ip!, size: 200),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: Text(_ip!, style: t.textTheme.labelLarge)),
                    const SizedBox(height: 24),
                    if (_round == 0) ...[
                      const SectionLabel('Time control', icon: Icons.timer_outlined),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final tc in const ['3+0', '5+0', '10+0', '5+3'])
                            ChoiceChip(label: Text(tc), selected: _timeControl == tc, onSelected: (_) => setState(() => _timeControl = tc)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    SectionLabel(_round == 0 ? 'Lobby (${_lobby.length})' : 'Round $_round', icon: Icons.people_outline),
                    if (_lobby.isEmpty)
                      Text('Waiting for players to join…', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))
                    else if (_round == 0)
                      HcListGroup(children: [
                        for (final p in _lobby) HcListRow(leading: HcAvatar(name: p.username), title: p.username),
                      ])
                    else
                      HcListGroup(children: [
                        for (final p in _activePairings.values)
                          HcListRow(
                            leading: Icon(Icons.sports_esports_outlined, color: t.colorScheme.onSurfaceVariant),
                            title: p.blackId == null
                                ? '${_standings[p.whiteId]?.username} -- bye'
                                : '${_standings[p.whiteId]?.username} vs ${_standings[p.blackId]?.username}',
                          ),
                      ]),
                    const SizedBox(height: HcSpace.s4),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _lobby.length >= 2 && _activePairings.isEmpty ? _startRound : null,
                        child: Text(_round == 0 ? 'Start round 1' : 'Start round ${_round + 1}'),
                      ),
                    ),
                    if (sorted.isNotEmpty) ...[
                      const SizedBox(height: HcSpace.s4),
                      const SectionLabel('Standings', icon: Icons.leaderboard_outlined),
                      HcListGroup(children: [
                        for (var i = 0; i < sorted.length; i++)
                          HcListRow(
                            leading: SizedBox(width: 24, child: Text('${i + 1}', textAlign: TextAlign.center, style: HcText.ratingMd.copyWith(color: hc.ink3))),
                            title: sorted[i].username,
                            trailing: Text('${sorted[i].points}', style: HcText.ratingMd.copyWith(color: hc.ink)),
                          ),
                      ]),
                    ],
                  ],
                ),
    );
  }
}
