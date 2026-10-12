import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/ui.dart';
import 'tournament_detail_screen.dart';

/// Tournaments main tab: live, scheduled and completed events (GET /tournaments).
class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  List<Map<String, dynamic>>? _rows;
  Map<String, int> _counts = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final r = await Api.instance.get('/tournaments') as Map<String, dynamic>;
      final counts = (r['counts'] as Map).cast<String, dynamic>().map((k, v) => MapEntry(k, v as int));
      if (mounted) {
        setState(() {
          _rows = (r['tournaments'] as List).cast<Map<String, dynamic>>();
          _counts = counts;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final live = (rows ?? []).where((t) => t['status'] == 'live').toList();
    final scheduled = (rows ?? []).where((t) => t['status'] == 'scheduled').toList();
    final completed = (rows ?? []).where((t) => t['status'] == 'completed').toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const TabHeader(title: 'Tournaments', subtitle: 'Swiss and Arena events, live standings'),
          if (rows == null && _error == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(_error!, textAlign: TextAlign.center)),
            ),
          if (rows != null) ...[
            _Section(title: 'Live now', icon: Icons.podcasts, rows: live, counts: _counts),
            _Section(title: 'Scheduled', icon: Icons.schedule, rows: scheduled, counts: _counts),
            _Section(title: 'Completed', icon: Icons.flag_outlined, rows: completed, counts: _counts),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.rows, required this.counts});
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> rows;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(title, icon: icon),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Nothing here yet.', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          )
        else
          ...rows.map((r) => _TournamentCard(row: r, entrants: counts[r['id']] ?? 0)),
      ]),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.row, required this.entrants});
  final Map<String, dynamic> row;
  final int entrants;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final feeKobo = row['entry_fee_kobo'] as int? ?? 0;
    final minTier = row['min_tier'] as String? ?? 'free';
    final starts = DateTime.tryParse(row['starts_at'] as String? ?? '');
    final subtitleParts = [
      _typeLabel(row['type'] as String?),
      row['time_control'],
      row['variant'],
      if (row['rated'] == false) 'casual',
      if (feeKobo > 0) '₦${(feeKobo / 100).round()}',
      if (minTier != 'free') '$minTier+',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: row['id'] as String)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.colorScheme.secondary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.emoji_events, color: t.colorScheme.secondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row['name'] as String, style: t.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline, size: 13, color: t.colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('$entrants/${row['max_players']}', style: t.textTheme.labelSmall),
              ]),
              if (starts != null) ...[
                const SizedBox(height: 4),
                Text(_relativeTime(starts), style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
            ]),
          ]),
        ),
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

String _relativeTime(DateTime d) {
  final diff = d.difference(DateTime.now());
  if (diff.isNegative) return 'started';
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'in ${diff.inHours}h';
  return 'in ${diff.inDays}d';
}
