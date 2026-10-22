import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'endgame_trainer_screen.dart';

/// "The website's endgame drills: win or hold the position against the engine." Lists
/// GET /endgames grouped by category, with each drill's progress (GET /endgames/progress).
class EndgamesListScreen extends StatefulWidget {
  const EndgamesListScreen({super.key});

  @override
  State<EndgamesListScreen> createState() => _EndgamesListScreenState();
}

class _EndgamesListScreenState extends State<EndgamesListScreen> {
  List<Map<String, dynamic>>? _endgames;
  List<Map<String, dynamic>> _categories = [];
  Map<String, Map<String, dynamic>> _progress = {}; // endgame id -> progress
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/endgames') as Map;
      final endgames = (r['endgames'] as List).cast<Map<String, dynamic>>();
      final categories = (r['categories'] as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> progress = const [];
      try {
        progress = ((await Api.instance.get('/endgames/progress')) as List).cast<Map<String, dynamic>>();
      } on ApiError {
        // Best-effort; the list still works without known progress.
      }
      if (!mounted) return;
      setState(() {
        _endgames = endgames;
        _categories = categories;
        _progress = {for (final p in progress) p['endgame_id'] as String: p};
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final endgames = _endgames;
    return Scaffold(
      appBar: AppBar(title: const Text('Endgame drills')),
      body: endgames == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(HcSpace.s4),
                children: [
                  for (final cat in _categories) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(cat['label'] as String, style: HcText.label.copyWith(color: hc.green)),
                    ),
                    HcListGroup(children: [
                      for (final e in endgames.where((e) => e['category'] == cat['id']))
                        HcListRow(
                          title: e['title'] as String,
                          subtitle: _subtitleFor(e),
                          trailing: _progress[e['id']]?['completed'] == true
                              ? Icon(Icons.check_circle_rounded, color: hc.green)
                              : Icon(Icons.chevron_right_rounded, color: hc.ink3),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EndgameTrainerScreen(endgame: e),
                          )).then((_) => _load()),
                        ),
                    ]),
                    const SizedBox(height: HcSpace.s4),
                  ],
                ],
              ),
            ),
    );
  }

  String _subtitleFor(Map<String, dynamic> e) {
    final difficulty = '★' * (e['difficulty'] as num).toInt();
    final p = _progress[e['id']];
    if (p == null) return difficulty;
    final best = p['best_move_count'];
    return best != null ? '$difficulty · best $best moves' : '$difficulty · ${p['attempts']} ${p['attempts'] == 1 ? 'attempt' : 'attempts'}';
  }
}
