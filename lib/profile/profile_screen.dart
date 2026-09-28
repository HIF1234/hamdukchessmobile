import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/push.dart';
import '../core/settings.dart';
import '../core/ui.dart';
import 'leaderboard_screen.dart';

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
    final account = _me?['account'] as Map?;
    final ratings = (_me?['ratings'] as List?) ?? const [];
    final puzzles = _me?['puzzles'] as Map?;
    final username = account?['username'] as String? ?? 'Profile';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          TabHeader(
            title: username,
            subtitle: account != null ? '${account['tier']} · ${account['country'] ?? 'Unknown'}'.toUpperCase() : null,
            trailing: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white24,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!)),
              if (puzzles != null || ratings.isNotEmpty) ...[
                const SectionLabel('Ratings', icon: Icons.trending_up),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: [
                    if (puzzles != null)
                      _RatingCard(
                        label: 'Puzzles',
                        rating: '${puzzles['rating']}',
                        detail: '${puzzles['solved_count']} solved · streak ${puzzles['current_streak']}',
                      ),
                    for (final r in ratings.cast<Map>())
                      _RatingCard(
                        label: '${r['time_control']} ${r['variant'] == 'chess960' ? '960' : ''}'.trim(),
                        rating: '${r['rating']}',
                        detail: '${r['games_played']} games',
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                icon: const Icon(Icons.leaderboard_outlined),
                label: const Text('Leaderboard'),
              ),
              const SizedBox(height: 20),
              const SectionLabel('Settings', icon: Icons.settings_outlined),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListenableBuilder(
                    listenable: AppSettings.instance,
                    builder: (context, _) => SwitchListTile(
                      title: const Text('Low data mode'),
                      subtitle: Text('No pictures or animations. This session: ${DataMeter.label}.'),
                      value: AppSettings.instance.lowData,
                      onChanged: AppSettings.instance.setLowData,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('About & licences'),
                    subtitle: const Text('Open-source software used in this app'),
                    onTap: () => showLicensePage(context: context, applicationName: 'Hamduk Chess'),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await Push.stop();
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.label, required this.rating, required this.detail});
  final String label;
  final String rating;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            Text(rating, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(detail, style: t.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
