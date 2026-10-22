import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../profile/subscription_sheet.dart';
import 'opening_trainer_screen.dart';

const _categoryLabel = {
  'e4': '1. e4 Openings',
  'd4': '1. d4 Openings',
  'sicilian': 'Sicilian Systems',
  'indian': 'Indian Defences',
  'flank': 'Flank Openings',
  'closed': 'Closed Games',
};

/// "The website's 15 opening lines as move-by-move quizzes, repeated until remembered;
/// build your own repertoire with Gold." Lists GET /openings grouped by category, with each
/// line's progress (GET /openings/progress) and a bookmark toggle for the Gold-gated
/// personal repertoire (GET/POST/DELETE /openings/repertoire).
class OpeningsListScreen extends StatefulWidget {
  const OpeningsListScreen({super.key});

  @override
  State<OpeningsListScreen> createState() => _OpeningsListScreenState();
}

class _OpeningsListScreenState extends State<OpeningsListScreen> {
  List<Map<String, dynamic>>? _openings;
  Map<String, Map<String, dynamic>> _progress = {}; // eco -> progress
  Map<String, String> _repertoireIds = {}; // "eco:color" -> repertoire row id
  String _tier = 'free';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.instance.get('/openings'),
        Api.instance.get('/me'),
      ]);
      final openings = ((results[0] as Map)['openings'] as List).cast<Map<String, dynamic>>();
      final tier = (results[1] as Map)['account']?['tier'] as String? ?? 'free';
      List<Map<String, dynamic>> progress = const [];
      List<Map<String, dynamic>> repertoire = const [];
      try {
        progress = ((await Api.instance.get('/openings/progress')) as List).cast<Map<String, dynamic>>();
      } on ApiError {
        // Best-effort; the list still works without known progress.
      }
      if (tier == 'gold') {
        try {
          repertoire = ((await Api.instance.get('/openings/repertoire')) as List).cast<Map<String, dynamic>>();
        } on ApiError {
          // Best-effort.
        }
      }
      if (!mounted) return;
      setState(() {
        _openings = openings;
        _tier = tier;
        _progress = {for (final p in progress) p['eco'] as String: p};
        _repertoireIds = {for (final r in repertoire) '${r['eco']}:${r['color']}': r['id'] as String};
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleRepertoire(Map<String, dynamic> opening) async {
    if (_tier != 'gold') {
      await showSubscriptionSheet(context, _tier);
      return;
    }
    final key = '${opening['eco']}:${opening['color']}';
    final existingId = _repertoireIds[key];
    try {
      if (existingId != null) {
        await Api.instance.delete('/openings/repertoire/$existingId');
        if (mounted) setState(() => _repertoireIds = {..._repertoireIds}..remove(key));
      } else {
        final r = await Api.instance.post('/openings/repertoire', {'eco': opening['eco'], 'color': opening['color']}) as Map;
        if (mounted) setState(() => _repertoireIds = {..._repertoireIds, key: r['id'] as String? ?? ''});
      }
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final openings = _openings;
    return Scaffold(
      appBar: AppBar(title: const Text('Opening trainer')),
      body: openings == null
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
                  for (final cat in _groupBy(openings).entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _categoryLabel[cat.key] ?? cat.key,
                        style: HcText.label.copyWith(color: hc.green),
                      ),
                    ),
                    HcListGroup(children: [
                      for (final o in cat.value)
                        HcListRow(
                          title: o['name'] as String,
                          subtitle: _subtitleFor(o),
                          trailing: IconButton(
                            icon: Icon(
                              _repertoireIds.containsKey('${o['eco']}:${o['color']}') ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              color: _repertoireIds.containsKey('${o['eco']}:${o['color']}') ? hc.gold : hc.ink3,
                            ),
                            onPressed: () => _toggleRepertoire(o),
                          ),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => OpeningTrainerScreen(opening: o),
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

  String _subtitleFor(Map<String, dynamic> o) {
    final color = o['color'] == 'white' ? 'White' : 'Black';
    final p = _progress[o['eco']];
    if (p == null) return '$color repertoire · ${o['moves'].length} plies';
    return '$color repertoire · mastered to ply ${p['mastered_depth']} of ${o['moves'].length}';
  }

  Map<String, List<Map<String, dynamic>>> _groupBy(List<Map<String, dynamic>> items) {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final i in items) {
      out.putIfAbsent(i['category'] as String, () => []).add(i);
    }
    return out;
  }
}
