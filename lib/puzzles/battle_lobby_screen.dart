import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'battle_room_screen.dart';

/// Entry point for Puzzle Battle: find an opponent near your puzzle rating, or challenge a
/// friend with a link. Mirrors the website's /puzzles/battle lobby.
class BattleLobbyScreen extends StatefulWidget {
  const BattleLobbyScreen({super.key});

  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen> {
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>>? _recent;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final r = await Api.instance.get('/puzzles/battle/mine') as Map;
      if (mounted) setState(() => _recent = (r['battles'] as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // Best-effort; the lobby works fine without history.
    }
  }

  Future<void> _go(String path) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.instance.post(path) as Map;
      final battleId = r['battleId'] as String;
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: battleId)));
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final recent = _recent;
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Battle')),
      body: ListView(
        padding: const EdgeInsets.all(HcSpace.s4),
        children: [
          Icon(Icons.sports_kabaddi_rounded, size: 48, color: hc.gold),
          const SizedBox(height: HcSpace.s3),
          Text(
            'You and an opponent get the same puzzles. First to solve five wins. After three '
            'minutes, the higher score wins. A wrong move costs you that puzzle.',
            textAlign: TextAlign.center,
            style: HcText.bodySm.copyWith(color: hc.ink2),
          ),
          const SizedBox(height: HcSpace.s4),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: HcSpace.s3),
              child: Text(_error!, textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
            ),
          FilledButton.icon(
            style: HcButtons.large(),
            onPressed: _busy ? null : () => _go('/puzzles/battle/find'),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Find an opponent'),
          ),
          const SizedBox(height: HcSpace.s2),
          OutlinedButton.icon(
            style: HcButtons.large(),
            onPressed: _busy ? null : () => _go('/puzzles/battle/create'),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Challenge a friend'),
          ),
          const SizedBox(height: HcSpace.s2),
          Text(
            'Free accounts get 3 battles a day. Hamduk Plus and Gold are unlimited.',
            textAlign: TextAlign.center,
            style: HcText.bodySm.copyWith(color: hc.ink3),
          ),
          if (recent != null && recent.isNotEmpty) ...[
            const SizedBox(height: HcSpace.s6),
            Text('Recent battles', style: HcText.titleSm.copyWith(color: hc.ink)),
            const SizedBox(height: HcSpace.s2),
            for (final b in recent)
              HcListRow(
                title: 'vs ${b['opponent']}',
                subtitle: '${b['mine']}–${b['theirs']}',
                trailing: Text(
                  (b['result'] as String).toUpperCase(),
                  style: HcText.bodySm.copyWith(
                    color: b['result'] == 'won' ? hc.green : (b['result'] == 'lost' ? hc.dangerInk : hc.ink2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
