import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'game_screen.dart';

/// Public games open to watch live (GET /spectate).
class SpectateScreen extends StatefulWidget {
  const SpectateScreen({super.key});

  @override
  State<SpectateScreen> createState() => _SpectateScreenState();
}

class _SpectateScreenState extends State<SpectateScreen> {
  List<Map<String, dynamic>>? _games;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/spectate') as Map<String, dynamic>;
      if (mounted) setState(() => _games = (r['games'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    return Scaffold(
      appBar: AppBar(title: const Text('Watch live')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: games == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : games!.isEmpty
                    ? EmptyState(
                        icon: Icons.visibility_outlined,
                        title: 'No public games live right now',
                        body: 'Check back soon, or start your own from the Play tab.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(HcSpace.s4),
                        children: [
                          HcListGroup(children: [
                            for (final g in games)
                              HcListRow(
                                leading: Icon(Icons.visibility_outlined, color: context.hc.ink2),
                                title: '${g['white']?['username'] ?? '?'} (${g['white']?['rating'] ?? '?'}) vs '
                                    '${g['black']?['username'] ?? '?'} (${g['black']?['rating'] ?? '?'})',
                                subtitle: '${g['time_control']} · move ${g['ply']}'
                                    '${(g['spectator_count'] as num?) != null && (g['spectator_count'] as num) > 0 ? ' · ${g['spectator_count']} watching' : ''}',
                                onTap: () {
                                  final me = Supabase.instance.client.auth.currentUser?.id;
                                  if (me == null) return;
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => GameScreen(gameId: g['id'] as String, myId: me),
                                  ));
                                },
                              ),
                          ]),
                        ],
                      ),
      ),
    );
  }
}
