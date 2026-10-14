import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'auth_errors.dart';

/// Shown in place of the app after the player taps a password-reset link, which signs them
/// into a recovery session with no new password yet. Supabase's own `updateUser` finishes it.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Choose a longer password -- at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _password.text));
      widget.onDone();
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
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
            Icon(Icons.lock_reset_rounded, size: 48, color: HcColors.brandGold),
            const SizedBox(height: HcSpace.s4),
            Text('Set a new password', style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
            const SizedBox(height: HcSpace.s7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(HcSpace.s5),
              decoration: BoxDecoration(color: hc.surface, borderRadius: BorderRadius.circular(HcRadius.xl)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: HcSpace.s3),
                  Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
                ],
                const SizedBox(height: HcSpace.s5),
                FilledButton(
                  style: HcButtons.large(),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save password'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
