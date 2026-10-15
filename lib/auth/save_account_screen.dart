import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'auth_errors.dart';
import 'check_your_email_screen.dart';

/// Turns the current guest (anonymous) session into a real account, in place -- the same
/// `auth.users` row, so every game and rating already played as a guest stays attached.
/// This is deliberately not the normal sign-up flow: `auth.signUp` would create a brand new
/// user and abandon this one's history, so this calls `updateUser` on the existing session
/// instead (Supabase's documented way to convert an anonymous user).
class SaveAccountScreen extends StatefulWidget {
  const SaveAccountScreen({super.key});

  @override
  State<SaveAccountScreen> createState() => _SaveAccountScreenState();
}

class _SaveAccountScreenState extends State<SaveAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Choose a longer password -- at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(email: email, password: _password.text));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CheckYourEmailScreen(
            email: email,
            otpType: OtpType.emailChange,
            onChangeEmail: () => Navigator.pop(context),
          ),
        ),
      );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(HcSpace.s6, HcSpace.s9, HcSpace.s6, HcSpace.s6),
          child: Column(children: [
            IconButton(
              alignment: Alignment.centerLeft,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: HcColors.onForest),
            ),
            Icon(Icons.shield_moon_outlined, size: 48, color: HcColors.brandGold),
            const SizedBox(height: HcSpace.s4),
            Text('Save your account', style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
            const SizedBox(height: HcSpace.s2),
            Text(
              'Add an email and password -- your games, puzzles and rating carry over exactly as they are.',
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
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: HcSpace.s3),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                      : const Text('Save my account'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
