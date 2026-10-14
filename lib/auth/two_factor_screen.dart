import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';

/// Turn two-factor sign-in (an authenticator-app code, each time) on or off. Mirrors the
/// website's TwoFactorSettings -- same Supabase MFA API, same enrol-then-verify flow.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _Enrolling {
  _Enrolling({required this.factorId, required this.qrSvg, required this.secret});
  final String factorId;
  final String qrSvg;
  final String secret;
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _loading = true;
  String? _factorId;
  _Enrolling? _enrolling;
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final factors = await Supabase.instance.client.auth.mfa.listFactors();
    final verified = factors.totp.where((f) => f.status == FactorStatus.verified);
    if (mounted) {
      setState(() {
        _factorId = verified.isEmpty ? null : verified.first.id;
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      // Supabase allows only one unverified factor at a time; clear any half-finished setup.
      final existing = await auth.mfa.listFactors();
      for (final f in existing.all) {
        if (f.status == FactorStatus.unverified) await auth.mfa.unenroll(f.id);
      }
      final res = await auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: 'Authenticator ${DateTime.now().toIso8601String().substring(0, 10)}',
        issuer: 'Hamduk Chess',
      );
      setState(() => _enrolling = _Enrolling(factorId: res.id, qrSvg: _decodeQr(res.totp!.qrCode), secret: res.totp!.secret));
    } catch (e) {
      setState(() => _error = "Couldn't start setup. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final enrolling = _enrolling;
    if (enrolling == null || _code.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.mfa
          .challengeAndVerify(factorId: enrolling.factorId, code: _code.text.trim());
      setState(() => _enrolling = null);
      _code.clear();
      await _refresh();
    } catch (_) {
      setState(() => _error = "That code didn't work. Try the newest one.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    final factorId = _factorId;
    if (factorId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off two-factor sign-in?'),
        content: const Text("You'll only need your password to sign in from now on."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it on')),
          FilledButton(style: HcButtons.danger(ctx), onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn off')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await Supabase.instance.client.auth.mfa.unenroll(factorId);
    if (mounted) setState(() => _busy = false);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Two-factor sign-in')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(HcSpace.s5),
                child: _enrolling != null ? _enrollForm(hc, _enrolling!) : _summary(hc),
              ),
      ),
    );
  }

  Widget _summary(HcPalette hc) {
    if (_factorId != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HcBanner(icon: Icons.shield_rounded, text: 'On', detail: "You'll be asked for a code each time you sign in.", tone: HcBannerTone.offer),
        const SizedBox(height: HcSpace.s4),
        OutlinedButton(onPressed: _busy ? null : _turnOff, child: const Text('Turn off')),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        'Protect your account with a code from an authenticator app, as well as your password. Recommended for coaches, organisers and staff.',
        style: HcText.body.copyWith(color: hc.ink2),
      ),
      const SizedBox(height: HcSpace.s4),
      FilledButton(style: HcButtons.large(), onPressed: _busy ? null : _start, child: const Text('Set up')),
      if (_error != null) ...[
        const SizedBox(height: HcSpace.s3),
        Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
      ],
    ]);
  }

  Widget _enrollForm(HcPalette hc, _Enrolling e) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('1. Scan this with Google Authenticator, Microsoft Authenticator, Authy or any authenticator app.', style: HcText.body.copyWith(color: hc.ink2)),
      const SizedBox(height: HcSpace.s4),
      Center(
        child: Container(
          width: 176,
          height: 176,
          padding: const EdgeInsets.all(HcSpace.s2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(HcRadius.md)),
          child: SvgPicture.string(e.qrSvg),
        ),
      ),
      const SizedBox(height: HcSpace.s4),
      Text("Can't scan? Enter this key instead:", style: HcText.bodySm.copyWith(color: hc.ink2)),
      const SizedBox(height: HcSpace.s1),
      SelectableText(e.secret, style: HcText.bodySm.copyWith(color: hc.ink, fontFamily: 'JetBrainsMono')),
      const SizedBox(height: HcSpace.s4),
      Text('2. Type the 6-digit code the app shows.', style: HcText.body.copyWith(color: hc.ink2)),
      const SizedBox(height: HcSpace.s3),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: HcText.titleLg.copyWith(color: hc.ink, letterSpacing: 4),
        decoration: const InputDecoration(labelText: 'Code', counterText: ''),
        onSubmitted: (_) => _confirm(),
      ),
      if (_error != null) ...[
        const SizedBox(height: HcSpace.s3),
        Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
      ],
      const SizedBox(height: HcSpace.s4),
      FilledButton(
        style: HcButtons.large(),
        onPressed: _busy ? null : _confirm,
        child: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Turn on'),
      ),
      const SizedBox(height: HcSpace.s2),
      TextButton(onPressed: () => setState(() => _enrolling = null), child: const Text('Cancel')),
    ]);
  }
}

/// Supabase's TOTP QR code arrives as an SVG data URI; strip the prefix down to raw SVG.
String _decodeQr(String qrCode) {
  final commaIndex = qrCode.indexOf(',');
  if (!qrCode.startsWith('data:') || commaIndex == -1) return qrCode;
  final meta = qrCode.substring(5, commaIndex);
  final data = qrCode.substring(commaIndex + 1);
  return meta.contains('base64') ? utf8.decode(base64.decode(data)) : Uri.decodeComponent(data);
}
