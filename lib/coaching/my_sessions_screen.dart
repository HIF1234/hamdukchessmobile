import 'package:flutter/material.dart';

import '../core/api.dart';

String _formatWhen(String iso) {
  final dt = DateTime.parse(iso).toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final suffix = dt.hour < 12 ? 'am' : 'pm';
  return '${months[dt.month - 1]} ${dt.day}, $h:${dt.minute.toString().padLeft(2, '0')}$suffix';
}

/// My coaching sessions as a student, and as a coach if I am one (GET /coaching/sessions).
class MySessionsScreen extends StatefulWidget {
  const MySessionsScreen({super.key});

  @override
  State<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends State<MySessionsScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/coaching/sessions') as Map<String, dynamic>;
      if (mounted) setState(() => _data = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _review(String sessionId) async {
    int rating = 5;
    final controller = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate this session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setDialogState(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(
                controller: controller,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Comment (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (submit != true || !mounted) return;
    try {
      await Api.instance.post('/coaching/sessions/$sessionId/review', {
        'rating': rating,
        if (controller.text.trim().isNotEmpty) 'comment': controller.text.trim(),
      });
      await _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asStudent = (_data?['asStudent'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final asCoach = (_data?['asCoach'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final reviewed = (_data?['reviewedSessionIds'] as List?)?.cast<String>() ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('My sessions')),
      body: _data == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('As student', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (asStudent.isEmpty)
                        const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('No sessions booked yet.'))
                      else
                        for (final s in asStudent)
                          _SessionCard(
                            session: s,
                            reviewed: reviewed.contains(s['id']),
                            onReview: () => _review(s['id'] as String),
                          ),
                      if (asCoach.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('As coach', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final s in asCoach) _SessionCard(session: s),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.reviewed = false, this.onReview});
  final Map<String, dynamic> session;
  final bool reviewed;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = session['status'] as String;
    final color = switch (status) {
      'confirmed' => theme.colorScheme.primary,
      'completed' => theme.colorScheme.onSurfaceVariant,
      'cancelled' => theme.colorScheme.error,
      _ => theme.colorScheme.secondary,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(_formatWhen(session['scheduled_at'] as String)),
        subtitle: Text('${session['duration_min']} min · ₦${((session['amount_kobo'] as int) / 100).round()}'),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
              child: Text(status.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ),
            if (status == 'completed' && onReview != null && !reviewed)
              TextButton(onPressed: onReview, child: const Text('Rate')),
            if (reviewed) Text('Rated', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
