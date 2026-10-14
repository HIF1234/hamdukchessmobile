// Supabase's own passkey API is marked @experimental (it's a beta feature on their side,
// not an unstable choice on ours); every call into it trips this lint.
// ignore_for_file: experimental_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'passkey_auth.dart';

/// Lists the signed-in player's registered passkeys, with buttons to add or
/// remove one. Profile → Settings → Passkeys.
class PasskeysScreen extends StatefulWidget {
  const PasskeysScreen({super.key});

  @override
  State<PasskeysScreen> createState() => _PasskeysScreenState();
}

class _PasskeysScreenState extends State<PasskeysScreen> {
  List<Passkey>? _passkeys;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Supabase.instance.client.auth.passkey.list();
      if (mounted) {
        setState(() {
          _passkeys = list;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your passkeys.');
    }
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PasskeyAuth.register();
      await _load();
    } catch (e) {
      if (!PasskeyAuth.isCancellation(e) && mounted) setState(() => _error = "Couldn't add a passkey. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Passkey p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this passkey?'),
        content: Text("You won't be able to sign in with ${p.friendlyName ?? 'this passkey'} anymore."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: HcButtons.danger(ctx), onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.auth.passkey.delete(passkeyId: p.id);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't remove that passkey.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final passkeys = _passkeys;
    return Scaffold(
      appBar: AppBar(title: const Text('Passkeys')),
      body: Padding(
        padding: const EdgeInsets.all(HcSpace.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Sign in with your face, fingerprint or a security key instead of a password.',
            style: HcText.bodySm.copyWith(color: hc.ink2),
          ),
          const SizedBox(height: HcSpace.s4),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: HcSpace.s3),
              child: Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
            ),
          Expanded(
            child: passkeys == null
                ? const Center(child: CircularProgressIndicator())
                : passkeys.isEmpty
                    ? EmptyState(
                        icon: Icons.fingerprint_rounded,
                        title: 'No passkeys yet',
                        body: 'Add one to sign in without typing a password.',
                      )
                    : ListView(children: [
                        HcListGroup(children: [
                          for (final p in passkeys)
                            HcListRow(
                              leading: Icon(Icons.fingerprint_rounded, color: hc.green),
                              title: p.friendlyName ?? 'Passkey',
                              subtitle: 'Added ${_relative(p.createdAt)}'
                                  '${p.lastUsedAt != null ? ' · last used ${_relative(p.lastUsedAt!)}' : ''}',
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: hc.ink2),
                                onPressed: () => _remove(p),
                              ),
                            ),
                        ]),
                      ]),
          ),
          const SizedBox(height: HcSpace.s4),
          FilledButton.icon(
            style: HcButtons.large(),
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_rounded),
            label: const Text('Add a passkey'),
          ),
        ]),
      ),
    );
  }
}

String _relative(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${at.day}/${at.month}/${at.year}';
}
