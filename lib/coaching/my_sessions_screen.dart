import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../core/ui.dart';

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
                    icon: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: context.hc.gold),
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
                    padding: const EdgeInsets.all(HcSpace.s4),
                    children: [
                      const SectionLabel('As student'),
                      if (asStudent.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: HcSpace.s4),
                          child: Text('No sessions booked yet.', style: HcText.bodySm.copyWith(color: context.hc.ink2)),
                        )
                      else
                        HcListGroup(children: [
                          for (final s in asStudent)
                            _SessionRow(session: s, reviewed: reviewed.contains(s['id']), onReview: () => _review(s['id'] as String)),
                        ]),
                      if (asCoach.isNotEmpty) ...[
                        const SizedBox(height: HcSpace.s4),
                        const SectionLabel('As coach'),
                        HcListGroup(children: [for (final s in asCoach) _SessionRow(session: s)]),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, this.reviewed = false, this.onReview});
  final Map<String, dynamic> session;
  final bool reviewed;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final status = session['status'] as String;
    final (Color bg, Color fg) = switch (status) {
      'confirmed' => (hc.greenSoft, hc.green),
      'completed' => (hc.surface2, hc.ink2),
      'cancelled' => (hc.dangerSoft, hc.dangerInk),
      _ => (hc.goldSoft, hc.goldInk),
    };
    return HcListRow(
      title: _formatWhen(session['scheduled_at'] as String),
      subtitle: '${session['duration_min']} min · ${hcNaira(session['amount_kobo'] as int)}',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: HcSpace.s2, vertical: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(HcRadius.xs)),
            child: Text(status.toUpperCase(), style: HcText.label.copyWith(fontSize: 11, color: fg)),
          ),
          if (status == 'completed' && onReview != null && !reviewed)
            TextButton(onPressed: onReview, child: const Text('Rate')),
          if (reviewed) Text('Rated', style: HcText.label.copyWith(fontSize: 11, color: hc.ink3)),
        ],
      ),
    );
  }
}
