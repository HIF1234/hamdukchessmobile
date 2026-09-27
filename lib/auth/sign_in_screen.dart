import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _site = 'https://play.chess.hamduk.com.ng';

enum _Mode { signIn, signUp, reset }

/// Sign in, create an account, or reset a password. Same rules as the website: new accounts
/// confirm their email first; password resets finish on the website.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

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
            emailRedirectTo: '$_site/play',
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
    final t = Theme.of(context);
    final title = switch (_mode) {
      _Mode.signIn => 'Sign in',
      _Mode.signUp => 'Create your account',
      _Mode.reset => 'Reset your password',
    };
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              Text('Hamduk Chess', style: t.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: t.textTheme.titleMedium),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              if (_mode == _Mode.signUp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  autofillHints: const [AutofillHints.newUsername],
                  decoration: const InputDecoration(
                    labelText: 'Username (optional)',
                    helperText: 'Letters, numbers and underscores',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_mode != _Mode.reset) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: [_mode == _Mode.signUp ? AutofillHints.newPassword : AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  onSubmitted: (_) => _submit(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: t.colorScheme.error)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!, style: TextStyle(color: t.colorScheme.primary)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(switch (_mode) {
                          _Mode.signIn => 'Sign in',
                          _Mode.signUp => 'Create account',
                          _Mode.reset => 'Send reset link',
                        }),
                ),
              ),
              const SizedBox(height: 12),
              if (_mode == _Mode.signIn) ...[
                TextButton(onPressed: () => _switch(_Mode.signUp), child: const Text('New here? Create a free account')),
                TextButton(onPressed: () => _switch(_Mode.reset), child: const Text('Forgot password?')),
              ] else
                TextButton(onPressed: () => _switch(_Mode.signIn), child: const Text('Back to sign in')),
            ],
          ),
        ),
      ),
    );
  }
}
