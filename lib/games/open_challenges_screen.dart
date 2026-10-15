import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'game_screen.dart';

/// Public challenges anyone can accept, showing rating and time control.
class OpenChallengesScreen extends StatefulWidget {
  const OpenChallengesScreen({super.key});

  @override
  State<OpenChallengesScreen> createState() => _OpenChallengesScreenState();
}

class _OpenChallengesScreenState extends State<OpenChallengesScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/challenges') as Map<String, dynamic>;
      if (mounted) setState(() => _rows = (r['challenges'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _accept(String id) async {
    try {
      final r = await Api.instance.post('/challenges/$id/accept') as Map;
      final gameId = r['gameId'] as String;
      final myId = Supabase.instance.client.auth.currentUser!.id;
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GameScreen(gameId: gameId, myId: myId),
      ));
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Open challenges')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? Center(child: Text(_error!))
            : rows == null
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No open challenges right now. Create one from Play.')),
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(HcSpace.s4),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final c = rows[i];
                          final creator = (c['creator'] as Map?)?['username'] as String? ?? 'A player';
                          final rating = (c['creator'] as Map?)?['rating'];
                          return HcListRow(
                            title: '$creator${rating != null ? ' ($rating)' : ''}',
                            subtitle:
                                '${c['time_control']} · ${c['variant'] == 'chess960' ? 'Chess960' : 'Standard'} · ${c['rated'] == true ? 'Rated' : 'Casual'}',
                            trailing: FilledButton(
                              onPressed: () => _accept(c['id'] as String),
                              child: const Text('Accept'),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
