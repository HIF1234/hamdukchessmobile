import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'coach_detail_screen.dart';

/// Browse active human coaches (GET /coaches).
class CoachesScreen extends StatefulWidget {
  const CoachesScreen({super.key});

  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen> {
  List<Map<String, dynamic>>? _coaches;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/coaches') as List;
      if (mounted) setState(() => _coaches = r.cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coaches')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _coaches == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : _coaches!.isEmpty
                    ? EmptyState(
                        icon: Icons.school_outlined,
                        title: 'No coaches are active right now',
                        body: 'Check back soon.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(HcSpace.s4),
                        children: [
                          HcListGroup(children: [for (final c in _coaches!) _CoachRow(coach: c)]),
                        ],
                      ),
      ),
    );
  }
}

class _CoachRow extends StatelessWidget {
  const _CoachRow({required this.coach});
  final Map<String, dynamic> coach;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final rate = (coach['hourly_rate_kobo'] as int? ?? 0);
    final rating = (coach['avg_rating'] as num?)?.toDouble() ?? 0;
    final specialties = (coach['specialties'] as List?)?.cast<String>() ?? const [];
    final name = coach['display_name'] as String? ?? '?';
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CoachDetailScreen(coachId: coach['id'] as String)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4, vertical: HcSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HcAvatar(name: name),
            const SizedBox(width: HcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [coach['fide_title'], name].where((e) => e != null && e != '').join(' '),
                    style: HcText.titleSm.copyWith(color: hc.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (coach['fide_elo'] != null) ...[
                    const SizedBox(height: 2),
                    Text('FIDE ${coach['fide_elo']}', style: HcText.bodySm.copyWith(color: hc.ink2)),
                  ],
                  if (specialties.isNotEmpty) ...[
                    const SizedBox(height: HcSpace.s1),
                    Wrap(
                      spacing: HcSpace.s1,
                      runSpacing: 4,
                      children: [
                        for (final s in specialties.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: HcSpace.s2, vertical: 2),
                            decoration: BoxDecoration(color: hc.surface2, borderRadius: BorderRadius.circular(HcRadius.xs)),
                            child: Text(s, style: HcText.label.copyWith(fontSize: 11, color: hc.ink2)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: HcSpace.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rating > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 14, color: hc.gold),
                    const SizedBox(width: 2),
                    Text(rating.toStringAsFixed(1), style: HcText.label.copyWith(fontSize: 12, color: hc.ink2)),
                  ]),
                const SizedBox(height: 2),
                Text('${hcNaira(rate)}/hr', style: HcText.ratingMd.copyWith(color: hc.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
