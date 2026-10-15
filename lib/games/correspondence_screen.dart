import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'game_screen.dart';

/// Daily (correspondence) games: your-move-first list, "create" by username, and holiday
/// mode (up to 14 days). 1/3/7 days a move -- the actual supported values on this server;
/// the spec's "1, 2, 3 or 5" doesn't match what createCorrespondenceGame validates today.
class CorrespondenceScreen extends StatefulWidget {
  const CorrespondenceScreen({super.key});

  @override
  State<CorrespondenceScreen> createState() => _CorrespondenceScreenState();
}

class _CorrespondenceScreenState extends State<CorrespondenceScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/correspondence') as Map<String, dynamic>;
      if (mounted) setState(() => _data = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final usernameCtrl = TextEditingController();
    var days = 1;
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('New daily game', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Opponent username')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final d in [1, 3, 7])
                  ChoiceChip(label: Text('$d day${d > 1 ? 's' : ''} a move'), selected: days == d, onSelected: (_) => set(() => days = d)),
              ]),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
            ]),
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    try {
      await Api.instance.post('/correspondence', {
        'opponentUsername': usernameCtrl.text.trim(),
        'daysPerMove': days,
      });
      await _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setVacation(int days) async {
    try {
      await Api.instance.post('/correspondence/vacation', {'days': days});
      await _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final games = (data?['games'] as List?)?.cast<Map<String, dynamic>>();
    List<Map<String, dynamic>>? sorted;
    if (games != null) {
      sorted = [...games]
        ..sort((a, b) {
          final am = a['myTurn'] == true;
          final bm = b['myTurn'] == true;
          return am == bm ? 0 : (am ? -1 : 1);
        });
    }
    final vacation = data?['vacation'] as Map?;
    final onVacation = vacation?['until'] != null && DateTime.tryParse(vacation?['until'] as String? ?? '')?.isAfter(DateTime.now()) == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily games'),
        actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: _create)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? Center(child: Text(_error!))
            : sorted == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(HcSpace.s4),
                    children: [
                      HcListRow(
                        title: onVacation ? 'Holiday mode is on' : 'Holiday mode',
                        subtitle: onVacation
                            ? 'Move deadlines are paused until ${vacation?['until']}'
                            : 'Pause your move deadlines for up to 14 days',
                        trailing: Switch(
                          value: onVacation,
                          onChanged: (v) => _setVacation(v ? 14 : 0),
                        ),
                      ),
                      const SizedBox(height: HcSpace.s4),
                      if (sorted.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No daily games yet. Tap + to challenge a friend.')),
                        )
                      else
                        for (final g in sorted)
                          HcListRow(
                            title: 'vs ${g['opponent']}',
                            subtitle: '${g['myTurn'] == true ? 'Your move' : "Opponent's move"} · ${g['daysPerMove']} day/move',
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: g['status'] == 'active'
                                ? () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                        gameId: g['id'] as String,
                                        myId: Supabase.instance.client.auth.currentUser!.id,
                                      ),
                                    ))
                                : null,
                          ),
                    ],
                  ),
      ),
    );
  }
}
