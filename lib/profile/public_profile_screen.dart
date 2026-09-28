import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../games/game_screen.dart';

/// Another player's public profile: rank, ratings and recent games (GET /profile/{username}).
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.username});
  final String username;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/profile/${widget.username}') as Map<String, dynamic>;
      if (mounted) setState(() => _data = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final data = _data;
    final profile = data?['profile'] as Map<String, dynamic>?;
    final games = (data?['games'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: _error != null
          ? Center(child: Text(_error!))
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : profile == null
                  ? const Center(child: Text('Player not found.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 28,
                            child: Text(
                              (profile['username'] as String).isNotEmpty ? (profile['username'] as String)[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(profile['username'] as String, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Rank #${data['rank']} · ${profile['country'] ?? 'Unknown'}'),
                            ]),
                          ),
                          Column(children: [
                            Text('${profile['rating']}', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const Text('rating', style: TextStyle(fontSize: 11)),
                          ]),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          '${profile['wins']}W / ${profile['losses']}L / ${profile['draws']}D · ${profile['games_played']} games',
                          style: t.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Text('Recent games', style: t.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final g in games)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () {
                                final me = Supabase.instance.client.auth.currentUser?.id;
                                if (me == null) return;
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => GameScreen(gameId: g['id'] as String, myId: me),
                                ));
                              },
                              title: Text('vs ${g['opponent'] ?? '—'}'),
                              subtitle: Text(g['timeControl'] as String? ?? ''),
                              trailing: Text(
                                switch (g['outcome']) {
                                  'win' => 'Won',
                                  'loss' => 'Lost',
                                  'draw' => 'Draw',
                                  _ => '…',
                                },
                                style: TextStyle(fontWeight: FontWeight.bold, color: g['outcome'] == 'win' ? Colors.green.shade700 : null),
                              ),
                            ),
                          ),
                        if (games.isEmpty) const Text('No games yet.'),
                      ],
                    ),
    );
  }
}
