import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import 'game_screen.dart';

/// Always shows the top game being played -- the public game with the most spectators
/// right now. Re-checks every 20s and switches if a different game takes the lead.
class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  String? _gameId;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/spectate/tv') as Map<String, dynamic>;
      final game = r['game'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _gameId = game?['id'] as String?;
          _error = game == null ? 'No live games right now.' : null;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _gameId;
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('TV')),
        body: Center(child: Text(_error ?? '', textAlign: TextAlign.center)),
      );
    }
    return GameScreen(key: ValueKey(id), gameId: id, myId: Supabase.instance.client.auth.currentUser!.id);
  }
}
