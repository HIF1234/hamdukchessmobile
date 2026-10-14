import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'google_auth.dart';
import 'passkey_auth.dart';

const _site = 'https://play.chess.hamduk.com.ng';

enum _Mode { signIn, signUp, reset }

/// Sign in, create an account, or reset a password. Same rules as the website: new accounts
/// confirm their email first; password resets finish on the website.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.config});
  final AppConfig config;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _error;
  String? _info;

  static final _usernameRule = RegExp(r'^[a-z0-9_]{3,20}$');

  void _switch(_Mode m) => setState(() {
        _mode = m;
        _error = null;
        _info = null;
      });

  Future<void> _signInWithGoogle() async {
    final clientId = widget.config.googleWebClientId;
    if (clientId == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await GoogleAuth.signIn(clientId);
    } catch (e) {
      if (!GoogleAuth.isCancellation(e)) {
        setState(() => _error = 'Google sign-in failed. Try again, or use your email.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await PasskeyAuth.signIn();
    } catch (e) {
      if (!PasskeyAuth.isCancellation(e)) {
        setState(() => _error = 'Passkey sign-in failed. Try again, or use your email.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No connection. Check your data or Wi-Fi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return setState(() => _error = 'Enter your email address.');
    if (_mode != _Mode.reset && _password.text.length < 6) {
      return setState(() => _error = 'Passwords are at least 6 characters.');
    }
    final username = _username.text.trim().toLowerCase();
    if (_mode == _Mode.signUp && username.isNotEmpty && !_usernameRule.hasMatch(username)) {
      return setState(() => _error = 'Usernames are 3–20 letters, numbers or underscores.');
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      switch (_mode) {
        case _Mode.signIn:
          await auth.signInWithPassword(email: email, password: _password.text);
        case _Mode.signUp:
          final r = await auth.signUp(
            email: email,
            password: _password.text,
            data: {if (username.isNotEmpty) 'username': username},
            // Lands on our verified Android App Link; supabase_flutter's own deep-link
            // handling then signs the app in directly, without opening a browser.
            emailRedirectTo: '$_site/auth/callback',
          );
          if (r.session == null) {
            _switch(_Mode.signIn);
            setState(() => _info = 'Almost there! Check $email for a link to confirm your account, then sign in here.');
          }
        case _Mode.reset:
          await auth.resetPasswordForEmail(email, redirectTo: '$_site/reset-password');
          _switch(_Mode.signIn);
          setState(() => _info = 'If $email has an account, a reset link is on its way. Set a new password, then sign in here.');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No connection. Check your data or Wi-Fi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final title = switch (_mode) {
      _Mode.signIn => 'Sign in',
      _Mode.signUp => 'Create your account',
      _Mode.reset => 'Reset your password',
    };
    return Scaffold(
      backgroundColor: HcColors.forest,
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const AsoOkeStrip(),
              Padding(
                padding: const EdgeInsets.fromLTRB(HcSpace.s6, HcSpace.s9, HcSpace.s6, HcSpace.s6),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Hamduk ', style: HcText.displayLg.copyWith(color: HcColors.onForest)),
                        TextSpan(text: 'Chess', style: HcText.displayLg.copyWith(color: HcColors.brandGold)),
                      ]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HcSpace.s2),
                    Text('Africa-first chess', style: HcText.body.copyWith(color: HcColors.onForest2), textAlign: TextAlign.center),
                    const SizedBox(height: HcSpace.s7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(HcSpace.s5),
                      decoration: BoxDecoration(color: hc.surface, borderRadius: BorderRadius.circular(HcRadius.xl)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: HcText.displayMd.copyWith(color: hc.ink), textAlign: TextAlign.center),
                          const SizedBox(height: HcSpace.s5),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(labelText: 'Email'),
                          ),
                          if (_mode == _Mode.signUp) ...[
                            const SizedBox(height: HcSpace.s3),
                            TextField(
                              controller: _username,
                              autofillHints: const [AutofillHints.newUsername],
                              decoration: const InputDecoration(
                                labelText: 'Username (optional)',
                                helperText: 'Letters, numbers and underscores',
                              ),
                            ),
                          ],
                          if (_mode != _Mode.reset) ...[
                            const SizedBox(height: HcSpace.s3),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              autofillHints: [_mode == _Mode.signUp ? AutofillHints.newPassword : AutofillHints.password],
                              decoration: const InputDecoration(labelText: 'Password'),
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: HcSpace.s3),
                            Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
                          ],
                          if (_info != null) ...[
                            const SizedBox(height: HcSpace.s3),
                            Text(_info!, style: HcText.bodySm.copyWith(color: hc.green)),
                          ],
                          const SizedBox(height: HcSpace.s5),
                          FilledButton(
                            style: HcButtons.large(),
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(switch (_mode) {
                                    _Mode.signIn => 'Sign in',
                                    _Mode.signUp => 'Create account',
                                    _Mode.reset => 'Send reset link',
                                  }),
                          ),
                          if (_mode != _Mode.reset) ...[
                            const SizedBox(height: HcSpace.s3),
                            Row(children: [
                              Expanded(child: Divider(color: hc.line)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: HcSpace.s2),
                                child: Text('or', style: HcText.bodySm.copyWith(color: hc.ink3)),
                              ),
                              Expanded(child: Divider(color: hc.line)),
                            ]),
                            const SizedBox(height: HcSpace.s3),
                            if (_mode == _Mode.signIn) ...[
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _signInWithPasskey,
                                icon: const Icon(Icons.fingerprint_rounded, size: 20),
                                label: const Text('Sign in with a passkey'),
                              ),
                              const SizedBox(height: HcSpace.s2),
                            ],
                            if (widget.config.googleWebClientId != null)
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _signInWithGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Continue with Google'),
                              ),
                            if (widget.config.googleWebClientId != null) const SizedBox(height: HcSpace.s2),
                            TextButton(
                              onPressed: _busy ? null : _continueAsGuest,
                              child: const Text('Continue as guest'),
                            ),
                          ],
                          const SizedBox(height: HcSpace.s2),
                          if (_mode == _Mode.signIn) ...[
                            TextButton(onPressed: () => _switch(_Mode.signUp), child: const Text('New here? Create a free account')),
                            TextButton(onPressed: () => _switch(_Mode.reset), child: const Text('Forgot password?')),
                          ] else
                            TextButton(onPressed: () => _switch(_Mode.signIn), child: const Text('Back to sign in')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
