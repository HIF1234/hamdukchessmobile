import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/sign_in_screen.dart';
import 'core/app_config.dart';
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

  final config = await AppConfig.load();
  if (config != null) {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
    final auth = Supabase.instance.client.auth;
    unawaited(Telemetry.setUser(auth.currentUser?.id));
    auth.onAuthStateChange.listen((s) => Telemetry.setUser(s.session?.user.id));
  }
  runApp(HamdukChessApp(config: config));
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
