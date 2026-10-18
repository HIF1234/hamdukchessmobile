import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../profile/subscription_sheet.dart';

/// "Moves played from this position by masters and on Hamduk, with their results."
/// Hamduk games are free; masters is Gold (enforced server-side, not just this toggle).
class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key, required this.fen});
  final String fen;

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  String _source = 'hamduk';
  Map? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.instance.post('/explorer', {'fen': widget.fen, 'source': _source}) as Map;
      if (mounted) setState(() => _result = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final r = _result;
    final moves = (r?['moves'] as List?)?.cast<Map>() ?? const [];
    final total = (r?['total'] as num?)?.toInt() ?? 0;
    final gold = r?['gold'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Opening explorer')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(HcSpace.s4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'hamduk', label: Text('Hamduk games')),
                ButtonSegment(value: 'masters', label: Text('Masters')),
              ],
              selected: {_source},
              onSelectionChanged: (s) {
                setState(() => _source = s.first);
                _load();
              },
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))))
          else if (_source == 'masters' && !gold)
            Expanded(
              child: EmptyState(
                icon: Icons.workspace_premium_outlined,
                title: 'Masters is a Gold feature',
                body: 'See how the strongest players handle this exact position.',
                actionLabel: 'Upgrade',
                onAction: () => showSubscriptionSheet(context, 'free'),
              ),
            )
          else if (moves.isEmpty)
            const Expanded(child: EmptyState(icon: Icons.travel_explore_outlined, title: 'No games found', body: 'Nobody has reached this exact position yet.'))
          else
            Expanded(
              child: ListView(
                children: [
                  for (final m in moves)
                    HcListRow(
                      title: m['san'] as String,
                      subtitle: '${hcNumber(((m['white'] as num) + (m['draws'] as num) + (m['black'] as num)).toInt())} games'
                          '${m['averageRating'] != null ? ' · avg ${m['averageRating']}' : ''}',
                      trailing: _ResultBar(white: (m['white'] as num).toInt(), draws: (m['draws'] as num).toInt(), black: (m['black'] as num).toInt()),
                    ),
                  if (total > 0 && !gold)
                    Padding(
                      padding: const EdgeInsets.all(HcSpace.s4),
                      child: Text('Showing the top moves. Gold shows up to 12.', style: HcText.bodySm.copyWith(color: hc.ink2)),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({required this.white, required this.draws, required this.black});
  final int white;
  final int draws;
  final int black;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final total = white + draws + black;
    if (total == 0) return const SizedBox.shrink();
    return SizedBox(
      width: 80,
      height: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HcRadius.xs),
        child: Row(children: [
          if (white > 0) Expanded(flex: white, child: ColoredBox(color: hc.green)),
          if (draws > 0) Expanded(flex: draws, child: ColoredBox(color: hc.ink3)),
          if (black > 0) Expanded(flex: black, child: ColoredBox(color: hc.ink)),
        ]),
      ),
    );
  }
}
