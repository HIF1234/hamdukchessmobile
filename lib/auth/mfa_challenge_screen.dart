import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';

/// Shown after sign-in, before the app, when the account has two-factor sign-in on. Mirrors
/// the website's MfaGate: the session is only AAL1 until this succeeds.
class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key, required this.factorId, required this.onVerified});
  final String factorId;
  final VoidCallback onVerified;

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(factorId: widget.factorId, code: _code.text.trim());
      widget.onVerified();
    } catch (_) {
      setState(() {
        _error = "That code didn't work. Check the time on your phone and try the newest code.";
        _code.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      backgroundColor: HcColors.forest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HcSpace.s6, HcSpace.s9, HcSpace.s6, HcSpace.s6),
          child: Column(children: [
            Icon(Icons.shield_rounded, size: 48, color: HcColors.brandGold),
            const SizedBox(height: HcSpace.s4),
            Text('Two-factor sign-in', style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
            const SizedBox(height: HcSpace.s2),
            Text(
              'Enter the 6-digit code from your authenticator app.',
              style: HcText.body.copyWith(color: HcColors.onForest2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HcSpace.s7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(HcSpace.s5),
              decoration: BoxDecoration(color: hc.surface, borderRadius: BorderRadius.circular(HcRadius.xl)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: HcText.titleLg.copyWith(color: hc.ink, letterSpacing: 4),
                  decoration: const InputDecoration(labelText: 'Code', counterText: ''),
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: HcSpace.s3),
                  Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk), textAlign: TextAlign.center),
                ],
                const SizedBox(height: HcSpace.s4),
                FilledButton(
                  style: HcButtons.large(),
                  onPressed: _busy ? null : _verify,
                  child: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify'),
                ),
                const SizedBox(height: HcSpace.s2),
                TextButton(
                  onPressed: _busy ? null : () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Sign out instead'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
