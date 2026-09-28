import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/ui.dart';
import 'game_screen.dart';
import 'game_state.dart';

/// Games in progress and recently finished ones (GET /games), so a player can find their
/// way back into a game or glance at recent results without digging through notifications.
class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  List<GameState>? _active;
  List<GameState>? _recent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/games') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _active = (r['active'] as List).cast<Map<String, dynamic>>().map(GameState.fromApi).toList();
        _recent = (r['recent'] as List).cast<Map<String, dynamic>>().map(GameState.fromApi).toList();
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _open(GameState g) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(gameId: g.id, myId: me)));
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final recent = _recent;
    return Scaffold(
      appBar: AppBar(title: const Text('Game history')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: active == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!)),
                  if (active != null && active.isNotEmpty) ...[
                    const SectionLabel('In progress', icon: Icons.play_circle_outline),
                    for (final g in active) _GameRow(game: g, onTap: () => _open(g)),
                    const SizedBox(height: 20),
                  ],
                  const SectionLabel('Recent games', icon: Icons.history),
                  if (recent != null && recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No finished games yet.', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  for (final g in recent ?? const <GameState>[]) _GameRow(game: g, onTap: () => _open(g)),
                ],
              ),
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.onTap});
  final GameState game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final me = Supabase.instance.client.auth.currentUser?.id;
    final isWhite = me == game.white.id;
    final opponent = isWhite ? game.black : game.white;
    final String resultLabel;
    final Color? resultColor;
    if (game.active) {
      resultLabel = 'In progress';
      resultColor = t.colorScheme.primary;
    } else if (game.result == 'draw') {
      resultLabel = 'Draw';
      resultColor = t.colorScheme.onSurfaceVariant;
    } else if (game.winnerId == me) {
      resultLabel = 'Won';
      resultColor = Colors.green.shade700;
    } else {
      resultLabel = 'Lost';
      resultColor = t.colorScheme.error;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(opponent.username.isNotEmpty ? opponent.username[0].toUpperCase() : '?')),
        title: Text('vs ${opponent.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(game.timeControl.isEmpty ? 'Correspondence' : game.timeControl),
        trailing: Text(resultLabel, style: t.textTheme.bodyMedium?.copyWith(color: resultColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
