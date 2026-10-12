import 'package:flutter/material.dart';

import '../core/api.dart';
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
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No coaches are active right now.')),
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _coaches!.length,
                        itemBuilder: (context, i) => _CoachCard(coach: _coaches![i]),
                      ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach});
  final Map<String, dynamic> coach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = ((coach['hourly_rate_kobo'] as int? ?? 0) / 100).round();
    final rating = (coach['avg_rating'] as num?)?.toDouble() ?? 0;
    final specialties = (coach['specialties'] as List?)?.cast<String>() ?? const [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CoachDetailScreen(coachId: coach['id'] as String)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  (coach['display_name'] as String? ?? '?').isNotEmpty
                      ? (coach['display_name'] as String)[0].toUpperCase()
                      : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          [coach['fide_title'], coach['display_name']].where((e) => e != null && e != '').join(' '),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rating > 0) ...[
                        Icon(Icons.star, size: 16, color: theme.colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(1), style: theme.textTheme.labelMedium),
                      ],
                    ]),
                    if (coach['fide_elo'] != null)
                      Text('FIDE ${coach['fide_elo']}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (specialties.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: specialties
                              .take(3)
                              .map((s) => Chip(
                                    label: Text(s, style: theme.textTheme.labelSmall),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ))
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text('₦$rate/hr', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
