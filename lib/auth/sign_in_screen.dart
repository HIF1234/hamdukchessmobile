import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/nigeria_states.dart';
import '../core/theme.dart';
import 'auth_errors.dart';
import 'check_your_email_screen.dart';
import 'google_auth.dart';
import 'passkey_auth.dart';

const _site = 'https://play.chess.hamduk.com.ng';

enum _Mode { signIn, signUp, reset }

/// Sign in, create an account, or reset a password. New accounts confirm their email first
/// (see [CheckYourEmailScreen]); password resets finish in the app, not on the website.
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
  final _guardianEmail = TextEditingController();
  final _passwordFocus = FocusNode();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  String? _info;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  String? _state;
  bool _termsAccepted = false;

  /// `under13`, `13_17` or `18_plus` -- sets the safety defaults, including whether online
  /// play needs a guardian's approval first.
  String? _ageBracket;

  Timer? _usernameDebounce;
  String? _usernameHelper;
  bool _usernameBlocked = false;

  static final _usernameRule = RegExp(r'^[a-z0-9_]{3,20}$');

  @override
  void dispose() {
    _passwordFocus.dispose();
    _guardianEmail.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _switch(_Mode m) => setState(() {
        _mode = m;
        _error = null;
        _info = null;
      });

  /// How long until the sign-in button unlocks again, or null when it isn't locked.
  Duration? get _lockRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative) {
      _lockedUntil = null;
      return null;
    }
    return left;
  }

  void _validateEmail() {
    final email = _email.text.trim().toLowerCase();
    if (email != _email.text) _email.text = email;
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
    }
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final username = value.trim().toLowerCase();
    if (username.isEmpty || !_usernameRule.hasMatch(username)) {
      setState(() {
        _usernameHelper = null;
        _usernameBlocked = false;
      });
      return;
    }
    setState(() => _usernameHelper = 'Checking…');
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () => _checkUsername(username));
  }

  Future<void> _checkUsername(String username) async {
    try {
      final res = await Api.instance.get('/username-available', {'username': username}) as Map;
      // The field may have moved on while this was in flight; ignore a stale reply.
      if (!mounted || _username.text.trim().toLowerCase() != username) return;
      final available = res['available'] == true;
      final suggestion = res['suggestion'] as String?;
      setState(() {
        _usernameBlocked = !available;
        _usernameHelper = available
            ? 'Available'
            : suggestion != null
                ? '$username is taken. Try $suggestion.'
                : "That username isn't available.";
      });
    } catch (_) {
      if (mounted && _username.text.trim().toLowerCase() == username) {
        setState(() => _usernameHelper = null);
      }
    }
  }

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
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_lockRemaining != null) return;
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return setState(() => _error = 'Enter a valid email address.');
    }
    if (_mode == _Mode.signUp && _password.text.length < 8) {
      return setState(() => _error = 'Choose a longer password -- at least 8 characters.');
    }
    final username = _username.text.trim().toLowerCase();
    if (_mode == _Mode.signUp && username.isNotEmpty && !_usernameRule.hasMatch(username)) {
      return setState(() => _error = 'Usernames are 3–20 letters, numbers or underscores.');
    }
    if (_mode == _Mode.signUp && username.isNotEmpty && _usernameBlocked) {
      return setState(() => _error = _usernameHelper ?? "That username isn't available.");
    }
    if (_mode == _Mode.signUp && _ageBracket == null) {
      return setState(() => _error = 'Select your age range.');
    }
    final guardianEmail = _guardianEmail.text.trim().toLowerCase();
    if (_mode == _Mode.signUp && _ageBracket == 'under13' &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(guardianEmail)) {
      return setState(() => _error = "Enter a parent or guardian's email.");
    }
    if (_mode == _Mode.signUp && !_termsAccepted) {
      return setState(() => _error = 'Agree to the Terms and Privacy Policy to continue.');
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
          _failedAttempts = 0;
          TextInput.finishAutofillContext(); // offers to save the password, now that it worked
        case _Mode.signUp:
          final r = await auth.signUp(
            email: email,
            password: _password.text,
            data: {
              if (username.isNotEmpty) 'username': username,
              'country': 'NG',
              if (_state != null) 'state': _state,
              'terms_accepted': 'true',
              if (_ageBracket != null) 'age_bracket': _ageBracket,
              if (_ageBracket == 'under13') 'guardian_email': guardianEmail,
            },
            // Lands on our verified Android App Link; supabase_flutter's own deep-link
            // handling then signs the app in directly, without opening a browser.
            emailRedirectTo: '$_site/auth/callback',
          );
          if (r.session == null && mounted) {
            TextInput.finishAutofillContext();
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CheckYourEmailScreen(email: email, onChangeEmail: () => Navigator.of(context).pop()),
            ));
          }
        case _Mode.reset:
          // The same app link as email confirmation; supabase_flutter notices the recovery
          // session and the auth gate shows the in-app "set a new password" screen for it.
          await auth.resetPasswordForEmail(email, redirectTo: '$_site/auth/callback');
          _switch(_Mode.signIn);
          setState(() => _info = 'If $email has an account, a reset link is on its way.');
      }
    } catch (e) {
      if (_mode == _Mode.signIn) {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          setState(() {
            _lockedUntil = DateTime.now().add(const Duration(minutes: 5));
            _error = 'Too many tries. Wait 5 minutes.';
          });
          if (mounted) setState(() => _busy = false);
          return;
        }
      }
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _passwordStrength() {
    final p = _password.text;
    if (p.isEmpty) return null;
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[0-9]').hasMatch(p) && RegExp(r'[a-zA-Z]').hasMatch(p)) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(p)) score++;
    return switch (score) { 0 || 1 => 'Weak', 2 => 'Fair', _ => 'Strong' };
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final title = switch (_mode) {
      _Mode.signIn => 'Sign in',
      _Mode.signUp => 'Create your account',
      _Mode.reset => 'Reset your password',
    };
    final lockRemaining = _lockRemaining;
    final strength = _mode == _Mode.signUp ? _passwordStrength() : null;
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
                    Semantics(
                      label: 'Hamduk Chess',
                      child: ExcludeSemantics(child: Image.asset('assets/branding/logo.png', width: 96, height: 96)),
                    ),
                    const SizedBox(height: HcSpace.s3),
                    ExcludeSemantics(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Hamduk ', style: HcText.displayLg.copyWith(color: HcColors.onForest)),
                          TextSpan(text: 'Chess', style: HcText.displayLg.copyWith(color: HcColors.brandGold)),
                        ]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: HcSpace.s2),
                    Text('Chess, Africa first', style: HcText.body.copyWith(color: HcColors.onForest2), textAlign: TextAlign.center),
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
                            textInputAction: _mode == _Mode.reset ? TextInputAction.done : TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(labelText: 'Email'),
                            onEditingComplete: _validateEmail,
                            onSubmitted: (_) => _mode == _Mode.reset ? _submit() : _passwordFocus.requestFocus(),
                          ),
                          if (_mode == _Mode.signUp) ...[
                            const SizedBox(height: HcSpace.s3),
                            TextField(
                              controller: _username,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newUsername],
                              decoration: InputDecoration(
                                labelText: 'Username (optional)',
                                helperText: _usernameHelper ?? 'Letters, numbers and underscores',
                                helperStyle: _usernameBlocked ? TextStyle(color: hc.dangerInk) : null,
                              ),
                              onChanged: _onUsernameChanged,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            const SizedBox(height: HcSpace.s4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('How old are you?', style: HcText.bodySm.copyWith(color: hc.ink2)),
                            ),
                            const SizedBox(height: HcSpace.s2),
                            Wrap(spacing: HcSpace.s2, runSpacing: HcSpace.s2, children: [
                              for (final (value, label) in const [
                                ('under13', 'Under 13'),
                                ('13_17', '13 to 17'),
                                ('18_plus', '18 or over'),
                              ])
                                ChoiceChip(
                                  label: Text(label),
                                  selected: _ageBracket == value,
                                  onSelected: (_) => setState(() => _ageBracket = value),
                                ),
                            ]),
                            if (_ageBracket == 'under13') ...[
                              const SizedBox(height: HcSpace.s3),
                              TextField(
                                controller: _guardianEmail,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: "Parent or guardian's email",
                                  helperText: 'They approve the account before you can play online',
                                ),
                              ),
                            ],
                            const SizedBox(height: HcSpace.s3),
                            DropdownButtonFormField<String>(
                              initialValue: _state,
                              decoration: const InputDecoration(labelText: 'State (optional) • Nigeria'),
                              items: [
                                for (final s in nigeriaStates) DropdownMenuItem(value: s, child: Text(s)),
                              ],
                              onChanged: (v) => setState(() => _state = v),
                            ),
                          ],
                          if (_mode != _Mode.reset) ...[
                            const SizedBox(height: HcSpace.s3),
                            TextField(
                              controller: _password,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: [_mode == _Mode.signUp ? AutofillHints.newPassword : AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                helperText: strength == null ? null : 'Strength: $strength',
                                suffixIcon: Semantics(
                                  label: _obscurePassword ? 'Show password' : 'Hide password',
                                  child: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                              ),
                              onChanged: _mode == _Mode.signUp ? (_) => setState(() {}) : null,
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: HcSpace.s3),
                            Semantics(
                              liveRegion: true,
                              child: Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
                            ),
                          ],
                          if (_info != null) ...[
                            const SizedBox(height: HcSpace.s3),
                            Text(_info!, style: HcText.bodySm.copyWith(color: hc.green)),
                          ],
                          if (_mode == _Mode.signUp) ...[
                            const SizedBox(height: HcSpace.s3),
                            Material(
                              type: MaterialType.transparency,
                              child: CheckboxListTile(
                                value: _termsAccepted,
                                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text('I agree to the Terms and Privacy Policy', style: HcText.bodySm.copyWith(color: hc.ink2)),
                              ),
                            ),
                          ],
                          const SizedBox(height: HcSpace.s5),
                          FilledButton(
                            style: HcButtons.large(),
                            onPressed: _busy ||
                                    lockRemaining != null ||
                                    (_mode == _Mode.signUp &&
                                        (!_termsAccepted || _ageBracket == null || _usernameBlocked))
                                ? null
                                : _submit,
                            child: _busy
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(lockRemaining != null
                                    ? 'Wait ${lockRemaining.inMinutes}:${(lockRemaining.inSeconds % 60).toString().padLeft(2, '0')}'
                                    : switch (_mode) {
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
                              child: const Text('Play as guest'),
                            ),
                          ],
                          const SizedBox(height: HcSpace.s2),
                          if (_mode == _Mode.signIn) ...[
                            TextButton(onPressed: () => _switch(_Mode.signUp), child: const Text('New here? Create a free account')),
                            TextButton(onPressed: () => _switch(_Mode.reset), child: const Text('Forgot password?')),
                          ] else
                            TextButton(onPressed: () => _switch(_Mode.signIn), child: const Text('Back to sign in')),
                          if (_mode != _Mode.reset) ...[
                            const SizedBox(height: HcSpace.s3),
                            Text.rich(
                              TextSpan(style: HcText.bodySm.copyWith(color: hc.ink3), children: [
                                const TextSpan(text: 'By continuing you agree to the '),
                                TextSpan(
                                  text: 'Terms',
                                  style: const TextStyle(decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()..onTap = () => _openSite(context, '/terms'),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()..onTap = () => _openSite(context, '/privacy'),
                                ),
                                const TextSpan(text: '.'),
                              ]),
                              textAlign: TextAlign.center,
                            ),
                          ],
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

void _openSite(BuildContext context, String path) {
  launchUrl(Uri.parse('$_site$path'), mode: LaunchMode.externalApplication);
}
