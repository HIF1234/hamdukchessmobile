import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'public_profile_screen.dart';

const _categories = <(String, String)>[
  ('bullet', 'Bullet'),
  ('blitz', 'Blitz'),
  ('rapid', 'Rapid'),
  ('classical', 'Classical'),
];

/// Top players by rating (GET /leaderboard).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _category = 'blitz';
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final r = await Api.instance.get('/leaderboard', {'category': _category}) as Map<String, dynamic>;
      if (mounted) setState(() => _rows = (r['rows'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3, vertical: HcSpace.s2),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (key, label) in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: HcSpace.s2),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _category == key,
                      onSelected: (_) {
                        setState(() => _category = key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: rows == null && _error == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : ListView(
                        padding: const EdgeInsets.all(HcSpace.s4),
                        children: [
                          HcListGroup(children: [
                            for (final r in rows!)
                              _LeaderboardRow(row: r, mine: r['user_id'] == myId),
                          ]),
                        ],
                      ),
          ),
        ),
      ]),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.row, required this.mine});
  final Map<String, dynamic> row;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final rank = row['rank'] as int;
    return DecoratedBox(
      decoration: BoxDecoration(color: mine ? hc.greenSoft : null),
      child: HcListRow(
        leading: SizedBox(
          width: 32,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: HcText.ratingMd.copyWith(color: rank <= 3 ? hc.goldInk : hc.ink3),
          ),
        ),
        title: row['username'] as String,
        subtitle: '${row['country'] ?? ''} · ${row['games']} games'.trim(),
        trailing: Text(hcNumber((row['rating'] as num).toInt()), style: HcText.ratingMd.copyWith(color: hc.ink)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PublicProfileScreen(username: row['username'] as String),
        )),
      ),
    );
  }
}
