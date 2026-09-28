import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
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
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: Center(child: Text('No public games live right now.')),
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: games.length,
                        itemBuilder: (context, i) {
                          final g = games[i];
                          final white = g['white'] as Map<String, dynamic>?;
                          final black = g['black'] as Map<String, dynamic>?;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.visibility_outlined),
                              title: Text(
                                '${white?['username'] ?? '?'} (${white?['rating'] ?? '?'}) vs '
                                '${black?['username'] ?? '?'} (${black?['rating'] ?? '?'})',
                              ),
                              subtitle: Text(
                                '${g['time_control']} · move ${g['ply']}'
                                '${(g['spectator_count'] as num?) != null && (g['spectator_count'] as num) > 0 ? ' · ${g['spectator_count']} watching' : ''}',
                              ),
                              onTap: () {
                                final me = Supabase.instance.client.auth.currentUser?.id;
                                if (me == null) return;
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => GameScreen(gameId: g['id'] as String, myId: me),
                                ));
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
