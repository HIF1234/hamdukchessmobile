import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';

const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _hhmm(int minute) {
  final h = minute ~/ 60;
  final m = minute % 60;
  final suffix = h < 12 ? 'am' : 'pm';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return m == 0 ? '$h12$suffix' : '$h12:${m.toString().padLeft(2, '0')}$suffix';
}

/// One coach: profile, availability, reviews, and booking (GET/POST /coaches/$id).
class CoachDetailScreen extends StatefulWidget {
  const CoachDetailScreen({super.key, required this.coachId});
  final String coachId;

  @override
  State<CoachDetailScreen> createState() => _CoachDetailScreenState();
}

class _CoachDetailScreenState extends State<CoachDetailScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/coaches/${widget.coachId}') as Map<String, dynamic>;
      if (mounted) setState(() => _data = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _book(int durationMin) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;

    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _booking = true);
    try {
      final r = await Api.instance.post('/coaches/${widget.coachId}/book', {
        'scheduled_at': when.toUtc().toIso8601String(),
        'duration_min': durationMin,
      }) as Map<String, dynamic>;
      final url = r['authorization_url'] as String?;
      if (url == null) throw ApiError('error', 'No checkout link returned.');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _showBookingSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session length', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pick a date and time next; it must fall inside the coach\'s availability below.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final d in [30, 60, 90])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _booking
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _book(d);
                          },
                    child: Text('$d minutes'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final coach = data?['coach'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: Text(coach?['display_name'] as String? ?? 'Coach')),
      body: data == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _Body(data: data!)),
      bottomNavigationBar: data == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: (AppConfig.current?.feature('coachBooking') ?? true)
                  ? FilledButton(
                      onPressed: _booking ? null : _showBookingSheet,
                      child: _booking
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Book a session'),
                    )
                  : const Text('Booking is temporarily unavailable.', textAlign: TextAlign.center),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coach = data['coach'] as Map<String, dynamic>;
    final availability = (data['availability'] as List).cast<Map<String, dynamic>>();
    final reviews = (data['reviews'] as List).cast<Map<String, dynamic>>();
    final rate = ((coach['hourly_rate_kobo'] as int? ?? 0) / 100).round();
    final specialties = (coach['specialties'] as List?)?.cast<String>() ?? const [];
    final languages = (coach['languages'] as List?)?.cast<String>() ?? const [];

    final byWeekday = <int, List<Map<String, dynamic>>>{};
    for (final s in availability) {
      byWeekday.putIfAbsent(s['weekday'] as int, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          if (coach['fide_elo'] != null) ...[
            Icon(Icons.military_tech_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text('FIDE ${coach['fide_elo']}', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 16),
          ],
          Icon(Icons.payments_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text('₦$rate/hr', style: theme.textTheme.bodyMedium),
          const Spacer(),
          if ((coach['avg_rating'] as num? ?? 0) > 0) ...[
            Icon(Icons.star, size: 18, color: theme.colorScheme.secondary),
            const SizedBox(width: 2),
            Text('${(coach['avg_rating'] as num).toStringAsFixed(1)} (${coach['rating_count']})', style: theme.textTheme.bodyMedium),
          ],
        ]),
        if ((coach['bio'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Text(coach['bio'] as String, style: theme.textTheme.bodyMedium),
        ],
        if (specialties.isNotEmpty || languages.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in specialties) Chip(label: Text(s)),
              for (final l in languages) Chip(label: Text(l), avatar: const Icon(Icons.language, size: 16)),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Availability', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (byWeekday.isEmpty)
          Text('No availability set yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var wd = 0; wd < 7; wd++)
                    if (byWeekday[wd] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 48, child: Text(_weekdays[wd], style: theme.textTheme.labelMedium)),
                            Expanded(
                              child: Text(
                                byWeekday[wd]!.map((s) => '${_hhmm(s['start_minute'] as int)}–${_hhmm(s['end_minute'] as int)}').join(', '),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Reviews (${reviews.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (reviews.isEmpty)
          Text('No reviews yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          HcListGroup(children: [
            for (final r in reviews)
              HcListRow(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < (r['rating'] as int) ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 16,
                      color: context.hc.gold,
                    ),
                  ),
                ),
                title: (r['comment'] as String?)?.isNotEmpty == true ? r['comment'] as String : 'No comment',
              ),
          ]),
        const SizedBox(height: 80),
      ],
    );
  }
}
