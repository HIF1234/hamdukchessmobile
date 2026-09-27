import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.instance.get('/me') as Map<String, dynamic>;
      if (mounted) setState(() => _me = me);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final account = _me?['account'] as Map?;
    final ratings = (_me?['ratings'] as List?) ?? const [];
    final puzzles = _me?['puzzles'] as Map?;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(account?['username'] as String? ?? 'Profile', style: t.textTheme.headlineSmall),
          if (account != null) Text('${account['tier']} · ${account['country'] ?? ''}'.toUpperCase()),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
          const SizedBox(height: 16),
          if (puzzles != null)
            ListTile(
              title: const Text('Puzzle rating'),
              trailing: Text('${puzzles['rating']}', style: t.textTheme.titleLarge),
              subtitle: Text('${puzzles['solved_count']} solved · streak ${puzzles['current_streak']}'),
            ),
          for (final r in ratings.cast<Map>())
            ListTile(
              title: Text('${r['time_control']} ${r['variant'] == 'chess960' ? '960' : ''}'),
              trailing: Text('${r['rating']}', style: t.textTheme.titleLarge),
              subtitle: Text('${r['games_played']} games'),
            ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Low data mode'),
              subtitle: Text('No pictures or animations. This session: ${DataMeter.label}.'),
              value: AppSettings.instance.lowData,
              onChanged: AppSettings.instance.setLowData,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
