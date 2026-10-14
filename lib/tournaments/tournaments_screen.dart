import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../local_play/local_tournament_home_screen.dart';
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
    final scheduled = (rows ?? []).where((t) => t['status'] == 'scheduled').toList()
      ..sort((a, b) => (a['starts_at'] as String? ?? '').compareTo(b['starts_at'] as String? ?? ''));
    final completed = (rows ?? []).where((t) => t['status'] == 'completed').toList();
    final featured = live.isNotEmpty ? live.first : (scheduled.isNotEmpty ? scheduled.first : null);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const ScreenHeader(title: 'Tournaments'),
          if (featured != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(HcSpace.s4, 0, HcSpace.s4, HcSpace.s4),
              child: _FeaturedTournamentHero(row: featured),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s4, HcSpace.s4, 0),
            child: HcListGroup(children: [
              HcListRow(
                leading: Icon(Icons.wifi_tethering_rounded, color: context.hc.ink2),
                title: 'Play without data',
                subtitle: 'Host or join a local tournament over WiFi -- no internet needed',
                trailing: Icon(Icons.chevron_right_rounded, color: context.hc.ink3),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalTournamentHomeScreen())),
              ),
            ]),
          ),
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

/// The next live or soonest-scheduled tournament, as the Tournaments tab's HeroCard.
class _FeaturedTournamentHero extends StatelessWidget {
  const _FeaturedTournamentHero({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final feeKobo = row['entry_fee_kobo'] as int? ?? 0;
    final starts = DateTime.tryParse(row['starts_at'] as String? ?? '');
    final isLive = row['status'] == 'live';
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: HeroCard.overline(isLive ? 'Happening now' : 'Up next')),
            if (isLive) const HcBadge.onHero('LIVE', icon: Icons.podcasts_rounded),
          ]),
          const SizedBox(height: HcSpace.s1),
          Text(row['name'] as String? ?? 'Tournament',
              style: HcText.displayMd.copyWith(color: HcColors.onForest), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: HcSpace.s1),
          HeroCard.sub([
            _typeLabel(row['type'] as String?),
            row['time_control'] as String?,
            if (starts != null && !isLive) _relativeTime(starts),
            feeKobo > 0 ? hcNaira(feeKobo) : 'Free',
          ].whereType<String>().join(' · ')),
          const SizedBox(height: HcSpace.s4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: HcButtons.large(),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: row['id'] as String))),
              child: const Text('Open'),
            ),
          ),
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
    final hc = context.hc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s4, HcSpace.s4, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(title, icon: icon),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HcSpace.s2),
            child: Text('Nothing here yet.', style: HcText.bodySm.copyWith(color: hc.ink2)),
          )
        else
          HcListGroup(children: [for (final r in rows) _TournamentRow(row: r, entrants: counts[r['id']] ?? 0)]),
      ]),
    );
  }
}

class _TournamentRow extends StatelessWidget {
  const _TournamentRow({required this.row, required this.entrants});
  final Map<String, dynamic> row;
  final int entrants;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final feeKobo = row['entry_fee_kobo'] as int? ?? 0;
    final minTier = row['min_tier'] as String? ?? 'free';
    final starts = DateTime.tryParse(row['starts_at'] as String? ?? '');
    final subtitleParts = [
      _typeLabel(row['type'] as String?),
      row['time_control'],
      row['variant'],
      if (row['rated'] == false) 'casual',
      if (feeKobo > 0) hcNaira(feeKobo),
      if (minTier != 'free') '$minTier+',
    ];

    return HcListRow(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: hc.goldSoft, borderRadius: BorderRadius.circular(HcRadius.sm)),
        child: Icon(Icons.emoji_events_rounded, color: hc.goldInk, size: 22),
      ),
      title: row['name'] as String,
      subtitle: subtitleParts.join(' · '),
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline_rounded, size: 13, color: hc.ink2),
          const SizedBox(width: 3),
          Text('$entrants/${row['max_players']}', style: HcText.label.copyWith(fontSize: 12, color: hc.ink2)),
        ]),
        if (starts != null) ...[
          const SizedBox(height: 4),
          Text(_relativeTime(starts), style: HcText.label.copyWith(fontSize: 12, color: hc.ink3)),
        ],
      ]),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: row['id'] as String)),
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
