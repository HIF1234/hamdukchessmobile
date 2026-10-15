import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/mfa_challenge_screen.dart';
import 'auth/reset_password_screen.dart';
import 'auth/sign_in_screen.dart';
import 'bots/bot_results.dart';
import 'core/api.dart';
import 'core/app_shortcuts.dart';
import 'core/app_config.dart';
import 'core/first_move.dart';
import 'core/force_update_screen.dart';
import 'core/links.dart';
import 'core/settings.dart';
import 'core/telemetry.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'home_shell.dart';
import 'onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase reads its settings from the app itself, so this works offline too.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Crash reports only from real installs; debug builds just print.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  _registerLicenses();
  await AppSettings.instance.load();
  final config = await AppConfig.load();
  AppConfig.current = config;
  final seenOnboarding = await hasSeenOnboarding();
  final appVersion = (await PackageInfo.fromPlatform()).version;
  if (config != null) {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
    final auth = Supabase.instance.client.auth;
    unawaited(Telemetry.setUser(auth.currentUser?.id));
    auth.onAuthStateChange.listen((s) => Telemetry.setUser(s.session?.user.id));
    if (auth.currentSession != null) unawaited(BotResults.sync());
  }
  unawaited(IncomingLinks.instance.start());
  unawaited(AppShortcuts.start());
  AppLifecycleListener(onPause: () => Telemetry.sessionData(bytes: DataMeter.bytes, since: DataMeter.started));
  // Phones stay upright so the board never becomes bigger than the screen; tablets (>=600dp
  // shortest side, the standard Material breakpoint) keep both orientations for the side-by-
  // side layout GameScreen switches to at that width.
  final view = PlatformDispatcher.instance.views.first;
  final shortestSideDp = (view.physicalSize.shortestSide / view.devicePixelRatio);
  if (shortestSideDp < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }
  runApp(HamdukChessApp(config: config, showOnboarding: !seenOnboarding, appVersion: appVersion));
}

/// Adds Stockfish and the piece set to the app's licences screen (Profile → About & licences).
/// Stockfish is GPL-3.0: the notice, where its source is, and the licence text are required.
void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final gpl = await rootBundle.loadString('assets/licenses/GPL-3.0.txt');
    yield LicenseEntryWithLineBreaks(['Stockfish'], '''
Hamduk Chess's bots use Stockfish 11, a free chess engine, unmodified. It runs as a separate
program on your phone and is licensed under the GNU General Public License version 3, below.

Complete source code of the version in this app, and the script used to build it:
https://play.chess.hamduk.com.ng/opensource/stockfish-sf_11-source.tar.gz
https://play.chess.hamduk.com.ng/opensource/stockfish-android-build.sh
Official project: https://github.com/official-stockfish/Stockfish (tag sf_11).

$gpl''');
    yield const LicenseEntryWithLineBreaks(['Chess pieces (cburnett, via react-chessboard)'], '''
Chess pieces by Colin M.L. Burnett. Taken from react-chessboard, MIT License,
Copyright (c) 2022 Ryan Gregory.''');
  });
}

class HamdukChessApp extends StatefulWidget {
  const HamdukChessApp({super.key, required this.config, required this.appVersion, this.showOnboarding = false});
  final AppConfig? config;
  final String appVersion;
  final bool showOnboarding;

  @override
  State<HamdukChessApp> createState() => _HamdukChessAppState();
}

class _HamdukChessAppState extends State<HamdukChessApp> {
  late bool _showOnboarding = widget.showOnboarding;

  /// A brand-new install, having just answered onboarding, goes straight into its first
  /// move rather than detouring through the sign-in screen -- the same anonymous session
  /// "Play as guest" creates there, just skipped ahead of. Signed-in/returning devices never
  /// see onboarding (hasSeenOnboarding), so this never runs for them.
  Future<void> _onOnboardingDone(OnboardingResult result) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously(data: {
          'starting_rating': '${result.startingRating}',
          'language': AppSettings.instance.language,
        });
        PendingFirstMove.set(result.beginner ? FirstMoveIntent.tutorial : FirstMoveIntent.bot);
      } catch (_) {
        // Offline, or the request failed: fall through to the ordinary sign-in screen.
      }
    }
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return MaterialApp(
      title: 'Hamduk Chess',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: config == null
          ? const _FirstRunOffline()
          : config.isBelowMinVersion(widget.appVersion)
              ? const ForceUpdateScreen()
              : _showOnboarding
                  ? OnboardingScreen(onDone: _onOnboardingDone)
                  : _AuthGate(config: config, appVersion: widget.appVersion),
    );
  }
}

/// Signed in: the app. Signed out: sign-in. Follows Supabase's session, which it keeps on
/// the device, so a signed-in player can open the app offline. Also catches two sessions
/// that shouldn't reach the app directly: a password-recovery link (shows the "set a new
/// password" screen instead) and a two-factor account that hasn't entered its code yet.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.config, required this.appVersion});
  final AppConfig config;
  final String appVersion;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _recovering = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.passwordRecovery) setState(() => _recovering = true);
      if (s.event == AuthChangeEvent.signedOut) setState(() => _recovering = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        if (auth.currentSession == null) return SignInScreen(config: widget.config);
        if (_recovering) {
          return ResetPasswordScreen(onDone: () => setState(() => _recovering = false));
        }
        return _MfaCheck(config: widget.config, appVersion: widget.appVersion);
      },
    );
  }
}

/// Checks whether this session still needs a two-factor code before showing the app.
class _MfaCheck extends StatefulWidget {
  const _MfaCheck({required this.config, required this.appVersion});
  final AppConfig config;
  final String appVersion;

  @override
  State<_MfaCheck> createState() => _MfaCheckState();
}

class _MfaCheckState extends State<_MfaCheck> {
  bool _loading = true;
  String? _pendingFactorId;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final auth = Supabase.instance.client.auth;
    final aal = auth.mfa.getAuthenticatorAssuranceLevel();
    String? factorId;
    if (aal.currentLevel == AuthenticatorAssuranceLevels.aal1 && aal.nextLevel == AuthenticatorAssuranceLevels.aal2) {
      final factors = await auth.mfa.listFactors();
      final verified = factors.totp.where((f) => f.status == FactorStatus.verified);
      factorId = verified.isEmpty ? null : verified.first.id;
    }
    if (mounted) {
      setState(() {
        _pendingFactorId = factorId;
        _loading = false;
      });
    }
    // Best-effort and idempotent server-side: a child only reaches here once their own email
    // is confirmed, which is also when it's safe to email their guardian the approval link.
    if (factorId == null) unawaited(Api.instance.post('/guardian-consent').catchError((_) => null));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final factorId = _pendingFactorId;
    if (factorId != null) {
      return MfaChallengeScreen(factorId: factorId, onVerified: () => setState(() => _pendingFactorId = null));
    }
    return HomeShell(config: widget.config, appVersion: widget.appVersion);
  }
}

class _FirstRunOffline extends StatelessWidget {
  const _FirstRunOffline();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Connect to the internet once to set up Hamduk Chess. After that, puzzles work offline.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
