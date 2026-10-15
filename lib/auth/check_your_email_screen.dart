import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'auth_errors.dart';

/// Shown right after sign-up, while the player waits to confirm their email -- either by
/// tapping the link (handled automatically via the app's deep link) or by typing the same
/// email's 6-digit code here.
class CheckYourEmailScreen extends StatefulWidget {
  const CheckYourEmailScreen({super.key, required this.email, required this.onChangeEmail, this.otpType = OtpType.signup});
  final String email;
  final VoidCallback onChangeEmail;

  /// `OtpType.signup` after a fresh sign-up; `OtpType.emailChange` when converting a guest
  /// (anonymous) session, since that confirms a changed email on an existing account instead.
  final OtpType otpType;

  @override
  State<CheckYourEmailScreen> createState() => _CheckYourEmailScreenState();
}

class _CheckYourEmailScreenState extends State<CheckYourEmailScreen> {
  final _code = TextEditingController();
  bool _useCode = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _resendIn = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
      } else if (mounted) {
        setState(() => _resendIn--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resend(type: widget.otpType, email: widget.email);
      _startCountdown();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_code.text.trim().length < 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .verifyOTP(type: widget.otpType, email: widget.email, token: _code.text.trim());
      // A verified session lands here automatically; the auth gate notices and moves on.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGmail() async {
    final gmail = Uri.parse('googlegmail://co');
    if (await canLaunchUrl(gmail)) {
      await launchUrl(gmail);
    } else {
      await launchUrl(Uri.parse('https://mail.google.com'), mode: LaunchMode.externalApplication);
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
            Icon(Icons.mark_email_unread_rounded, size: 48, color: HcColors.brandGold),
            const SizedBox(height: HcSpace.s4),
            Text('Check your email', style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
            const SizedBox(height: HcSpace.s2),
            Text(
              "We've sent a confirmation link to ${widget.email}. Tap it to finish, or enter the code from the same email below.",
              style: HcText.body.copyWith(color: HcColors.onForest2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HcSpace.s7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(HcSpace.s5),
              decoration: BoxDecoration(color: hc.surface, borderRadius: BorderRadius.circular(HcRadius.xl)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton.icon(
                  style: HcButtons.large(),
                  onPressed: _openGmail,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Gmail'),
                ),
                const SizedBox(height: HcSpace.s3),
                OutlinedButton(
                  onPressed: () => setState(() => _useCode = !_useCode),
                  child: Text(_useCode ? 'Use the link instead' : 'Prefer a code instead?'),
                ),
                if (_useCode) ...[
                  const SizedBox(height: HcSpace.s3),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: HcText.titleLg.copyWith(color: hc.ink, letterSpacing: 4),
                    decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
                    onSubmitted: (_) => _verifyCode(),
                  ),
                  const SizedBox(height: HcSpace.s3),
                  FilledButton(
                    style: HcButtons.large(),
                    onPressed: _busy ? null : _verifyCode,
                    child: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Confirm'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: HcSpace.s3),
                  Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk), textAlign: TextAlign.center),
                ],
                const SizedBox(height: HcSpace.s4),
                TextButton(
                  onPressed: _resendIn > 0 || _busy ? null : _resend,
                  child: Text(_resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend email'),
                ),
                TextButton(onPressed: widget.onChangeEmail, child: const Text('Wrong email? Change it')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
