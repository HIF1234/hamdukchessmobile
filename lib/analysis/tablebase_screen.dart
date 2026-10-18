import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../profile/subscription_sheet.dart';

const _categoryLabel = {
  'win': 'Win',
  'loss': 'Loss',
  'draw': 'Draw',
  'cursed-win': 'Cursed win (50-move draw)',
  'blessed-loss': 'Blessed loss (50-move draw)',
  'maybe-win': 'Maybe win',
  'maybe-loss': 'Maybe loss',
  'unknown': 'Unknown',
};

/// "The exact result and best moves with 7 pieces or fewer." Gold, enforced server-side.
class TablebaseScreen extends StatefulWidget {
  const TablebaseScreen({super.key, required this.fen});
  final String fen;

  @override
  State<TablebaseScreen> createState() => _TablebaseScreenState();
}

class _TablebaseScreenState extends State<TablebaseScreen> {
  Map? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.post('/tablebase', {'fen': widget.fen}) as Map;
      if (mounted) {
        setState(() {
          _result = r['result'] as Map?;
          _error = r['error'] as String?;
        });
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Endgame tablebase')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error == 'gold'
                ? EmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Tablebase is a Gold feature',
                    body: 'The exact result and best moves for any position with 7 pieces or fewer.',
                    actionLabel: 'Upgrade',
                    onAction: () => showSubscriptionSheet(context, 'free'),
                  )
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                    : r == null
                        ? const Center(child: Text('No result.'))
                        : ListView(
                            padding: const EdgeInsets.all(HcSpace.s4),
                            children: [
                              Text(
                                _categoryLabel[r['category']] ?? r['category'] as String,
                                style: HcText.titleLg.copyWith(color: hc.ink),
                              ),
                              if (r['dtz'] != null) Text('Distance to zero (50-move reset): ${r['dtz']}', style: HcText.bodySm.copyWith(color: hc.ink2)),
                              if (r['dtm'] != null) Text('Distance to mate: ${r['dtm']}', style: HcText.bodySm.copyWith(color: hc.ink2)),
                              const SizedBox(height: HcSpace.s4),
                              Text('Best moves', style: HcText.titleSm.copyWith(color: hc.ink)),
                              for (final m in (r['moves'] as List).cast<Map>())
                                HcListRow(
                                  title: m['san'] as String,
                                  subtitle: _categoryLabel[m['category']] ?? m['category'] as String,
                                  trailing: m['dtz'] != null ? Text('${m['dtz']}', style: HcText.bodySm.copyWith(color: hc.ink2)) : null,
                                ),
                            ],
                          ),
      ),
    );
  }
}
