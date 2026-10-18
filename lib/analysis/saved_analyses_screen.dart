import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import 'analysis_screen.dart';

/// "Save a position or game with notes, synced with the website." Lists this player's
/// saves; tapping one loads it back into the Analysis board.
class SavedAnalysesScreen extends StatefulWidget {
  const SavedAnalysesScreen({super.key});

  @override
  State<SavedAnalysesScreen> createState() => _SavedAnalysesScreenState();
}

class _SavedAnalysesScreenState extends State<SavedAnalysesScreen> {
  List<Map<String, dynamic>>? _analyses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/analyses') as Map;
      if (mounted) setState(() => _analyses = (r['analyses'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(Map<String, dynamic> a) async {
    try {
      final full = await Api.instance.get('/analyses/${a['id']}') as Map;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          startFen: full['start_fen'] as String,
          initialSanMoves: (full['moves'] as List?)?.cast<String>(),
        ),
      ));
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    try {
      await Api.instance.delete('/analyses/${a['id']}');
      if (mounted) setState(() => _analyses?.removeWhere((x) => x['id'] == a['id']));
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyses = _analyses;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved analyses')),
      body: analyses == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : analyses.isEmpty
              ? const EmptyState(icon: Icons.bookmark_border_rounded, title: 'Nothing saved yet', body: 'Save a position or game from the Analysis board to find it here.')
              : ListView(
                  children: [
                    for (final a in analyses)
                      HcListRow(
                        title: a['title'] as String,
                        subtitle: '${a['ply']} ${a['ply'] == 1 ? 'move' : 'moves'}',
                        trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(a)),
                        onTap: () => _open(a),
                      ),
                  ],
                ),
    );
  }
}
