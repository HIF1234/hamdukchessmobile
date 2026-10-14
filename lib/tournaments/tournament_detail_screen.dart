import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../games/game_screen.dart';

/// One tournament: standings, this round's pairings, join/withdraw (GET/POST /tournaments/$id).
class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});
  final String tournamentId;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/tournaments/${widget.tournamentId}') as Map<String, dynamic>;
      if (mounted) setState(() => _data = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('/tournaments/${widget.tournamentId}/join') as Map<String, dynamic>;
      if (!mounted) return;
      if (r['requiresPayment'] == true) {
        _showMessage(
          "This tournament has an entry fee. Finish payment on play.chess.hamduk.com.ng to confirm your spot.",
        );
      } else {
        _showMessage(r['alreadyJoined'] == true ? "You're already registered." : "You're in!");
      }
      await _load();
    } on ApiError catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    setState(() => _busy = true);
    try {
      await Api.instance.post('/tournaments/${widget.tournamentId}/withdraw');
      if (mounted) _showMessage('Withdrawn.');
      await _load();
    } on ApiError catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final t = data?['tournament'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: Text(t?['name'] as String? ?? 'Tournament')),
      body: data == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _Body(data: data!, busy: _busy, onJoin: _join, onWithdraw: _withdraw)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.busy, required this.onJoin, required this.onWithdraw});
  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hc = context.hc;
    final t = data['tournament'] as Map<String, dynamic>;
    final standings = (data['standings'] as List).cast<Map<String, dynamic>>();
    final games = (data['games'] as List).cast<Map<String, dynamic>>();
    final names = (data['names'] as Map).cast<String, dynamic>();
    final boards = (data['boards'] as List).cast<Map<String, dynamic>>();
    final myEntry = data['myEntry'] as Map<String, dynamic>?;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    final currentRound = t['current_round'] as int? ?? 0;
    final roundGames = games.where((g) => g['round'] == currentRound).toList();
    final status = t['status'] as String;
    final feeKobo = t['entry_fee_kobo'] as int? ?? 0;
    final minTier = t['min_tier'] as String? ?? 'free';

    String name(String? id) => id == null ? '—' : (names[id] as String? ?? '—');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _StatusChip(status: status),
                const Spacer(),
                if (feeKobo > 0) Text('₦${(feeKobo / 100).round()} entry', style: theme.textTheme.labelMedium),
              ]),
              const SizedBox(height: 10),
              Text(
                '${_typeLabel(t['type'] as String?)} · ${t['time_control']} · ${t['variant']}'
                '${t['rated'] == false ? ' · casual' : ''}'
                '${minTier != 'free' ? ' · $minTier+' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                t['type'] == 'arena'
                    ? 'Arena · ${t['duration_min']} min'
                    : 'Round ${t['current_round'] ?? 0} of ${t['rounds']}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if ((t['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(t['description'] as String, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 14),
              if (status == 'scheduled' && myEntry == null)
                FilledButton(onPressed: busy ? null : onJoin, child: const Text('Join tournament'))
              else if (myEntry != null && myEntry['status'] == 'active' && status != 'completed')
                OutlinedButton(onPressed: busy ? null : onWithdraw, child: const Text('Withdraw')),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        if (boards.isNotEmpty) ...[
          Text('Live boards', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: boards.length,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final b = boards[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (myId == null) return;
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(gameId: b['id'] as String, myId: myId)));
                  },
                  child: Container(
                    width: 92,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.sports_esports_outlined, color: theme.colorScheme.primary),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        Text(
          t['type'] == 'arena' ? 'Recent pairings' : 'Round ${t['current_round'] ?? 0} pairings',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (roundGames.isEmpty)
          Text('Pairings appear when the round starts.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          HcListGroup(children: [
            for (final g in roundGames)
              HcListRow(
                title: '${name(g['white_id'] as String?)} vs ${name(g['black_id'] as String?)}',
                trailing: Text(
                  switch (g['result']) {
                    null => 'in progress',
                    'draw' => '½–½',
                    'white' => '1–0',
                    _ => '0–1',
                  },
                  style: theme.textTheme.bodySmall,
                ),
                onTap: g['game_id'] == null || myId == null
                    ? null
                    : () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => GameScreen(gameId: g['game_id'] as String, myId: myId))),
              ),
          ]),

        const SizedBox(height: HcSpace.s6),
        Text('Standings (${standings.length}/${t['max_players']})', style: theme.textTheme.titleMedium),
        const SizedBox(height: HcSpace.s2),
        if (standings.isEmpty)
          Text('No entrants yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          HcListGroup(children: [
            for (var i = 0; i < standings.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(color: standings[i]['user_id'] == myId ? hc.greenSoft : null),
                child: HcListRow(
                  leading: SizedBox(width: 24, child: Text('${i + 1}', textAlign: TextAlign.center, style: HcText.ratingMd.copyWith(color: hc.ink3))),
                  title: name(standings[i]['user_id'] as String?),
                  subtitle: standings[i]['status'] != 'active' ? 'Withdrawn' : null,
                  trailing: Text('${standings[i]['score']}', style: HcText.ratingMd.copyWith(color: hc.ink)),
                ),
              ),
          ]),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = switch (status) {
      'live' => t.colorScheme.secondary,
      'completed' => t.colorScheme.onSurfaceVariant,
      _ => t.colorScheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
      child: Text(
        status == 'live' ? 'LIVE' : status.toUpperCase(),
        style: t.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _typeLabel(String? type) => switch (type) {
      'swiss' => 'Swiss',
      'arena' => 'Arena',
      'round_robin' => 'Round-robin',
      'knockout' => 'Knockout',
      _ => type ?? '',
    };
