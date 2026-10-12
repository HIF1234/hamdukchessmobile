import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';

/// Pricing must match TIER_PRICING in the backend's paystack-pricing.ts.
const _tiers = [
  (tier: 'plus', label: 'Hamduk Plus', monthlyNgn: 2500, perks: ['Unlimited puzzles', 'Deeper game review', 'No ads']),
  (tier: 'gold', label: 'Hamduk Gold', monthlyNgn: 7000, perks: ['Everything in Plus', 'Paid tournament entry', 'Priority support']),
];

/// Bottom sheet to upgrade from the current tier. Opens Paystack checkout in the
/// browser; the website's /billing page applies the upgrade on return, so the caller
/// should refresh /me after this sheet closes.
Future<void> showSubscriptionSheet(BuildContext context, String currentTier) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SubscriptionSheet(currentTier: currentTier),
  );
}

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet({required this.currentTier});
  final String currentTier;

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  String? _busyTier;
  String? _error;

  Future<void> _upgrade(String tier) async {
    setState(() {
      _busyTier = tier;
      _error = null;
    });
    try {
      final r = await Api.instance.post('/subscription/checkout', {'tier': tier}) as Map<String, dynamic>;
      final url = r['authorization_url'] as String?;
      if (url == null) throw ApiError('error', 'No checkout link returned.');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyTier = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Upgrade', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Opens Paystack in your browser. Come back here after paying and pull down to refresh.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
          ],
          for (final t in _tiers) ...[
            _TierCard(
              label: t.label,
              monthlyNgn: t.monthlyNgn,
              perks: t.perks,
              isCurrent: widget.currentTier == t.tier,
              busy: _busyTier == t.tier,
              disabled: _busyTier != null,
              onUpgrade: () => _upgrade(t.tier),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.label,
    required this.monthlyNgn,
    required this.perks,
    required this.isCurrent,
    required this.busy,
    required this.disabled,
    required this.onUpgrade,
  });
  final String label;
  final int monthlyNgn;
  final List<String> perks;
  final bool isCurrent;
  final bool busy;
  final bool disabled;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('₦$monthlyNgn/mo', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            ]),
            const SizedBox(height: 8),
            for (final p in perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(children: [
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p, style: theme.textTheme.bodySmall)),
                ]),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? const OutlinedButton(onPressed: null, child: Text('Current plan'))
                  : FilledButton(
                      onPressed: disabled ? null : onUpgrade,
                      child: busy
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Upgrade to $label'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
