import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/sign_in_screen.dart';
import 'bots/bot_results.dart';
import 'core/app_config.dart';
import 'core/settings.dart';
import 'core/telemetry.dart';
import 'firebase_options.dart';
import 'home_shell.dart';

const brandGreen = Color(0xFF22A05A);
const brandGold = Color(0xFFF5B82E);

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
  if (config != null) {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
    final auth = Supabase.instance.client.auth;
    unawaited(Telemetry.setUser(auth.currentUser?.id));
    auth.onAuthStateChange.listen((s) => Telemetry.setUser(s.session?.user.id));
    if (auth.currentSession != null) unawaited(BotResults.sync());
  }
  AppLifecycleListener(onPause: () => Telemetry.sessionData(bytes: DataMeter.bytes, since: DataMeter.started));
  runApp(HamdukChessApp(config: config));
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

class HamdukChessApp extends StatelessWidget {
  const HamdukChessApp({super.key, required this.config});
  final AppConfig? config;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: brandGreen, brightness: b, primary: brandGreen),
        );
    return MaterialApp(
      title: 'Hamduk Chess',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: config == null ? const _FirstRunOffline() : _AuthGate(config: config!),
    );
  }
}

/// Signed in: the app. Signed out: sign-in. Follows Supabase's session, which it keeps on
/// the device, so a signed-in player can open the app offline.
class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.config});
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) =>
          auth.currentSession == null ? const SignInScreen() : HomeShell(config: config),
    );
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
