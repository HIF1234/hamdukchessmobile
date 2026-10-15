import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/auth/sign_in_screen.dart';
import 'package:hamduk_chess/core/api.dart';
import 'package:hamduk_chess/core/app_config.dart';
import 'package:hamduk_chess/core/links.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// No googleWebClientId, so the Google button stays hidden and these tests exercise the
// email/password form the same way they would before Google sign-in existed.
final _noGoogleConfig = AppConfig(const {
  'supabase': {'url': 'https://x.supabase.co', 'anonKey': 'x'},
});

void main() {
  group('challenge links', () {
    const id = '1c8864bb-e639-4a3a-8b90-d49a112c50a6';

    test('a real challenge link gives its id', () {
      expect(challengeIdFrom(Uri.parse('https://play.chess.hamduk.com.ng/challenge/$id')), id);
    });

    test('game links (from notifications) give the game id', () {
      expect(gameIdFrom(Uri.parse('https://play.chess.hamduk.com.ng/play/$id')), id);
      expect(gameIdFrom(Uri.parse('https://play.chess.hamduk.com.ng/challenge/$id')), isNull);
      expect(gameIdFrom(Uri.parse('https://evil.example.com/play/$id')), isNull);
    });

    test('other pages, other sites and malformed ids are ignored', () {
      expect(challengeIdFrom(Uri.parse('https://play.chess.hamduk.com.ng/play/$id')), isNull);
      expect(challengeIdFrom(Uri.parse('https://evil.example.com/challenge/$id')), isNull);
      expect(challengeIdFrom(Uri.parse('https://play.chess.hamduk.com.ng.evil.com/challenge/$id')), isNull);
      expect(challengeIdFrom(Uri.parse('https://play.chess.hamduk.com.ng/challenge/not-an-id')), isNull);
      expect(challengeIdFrom(Uri.parse('https://play.chess.hamduk.com.ng/challenge/$id/extra')), isNull);
    });
  });

  group('sign-in screen', () {
    tearDown(() => Api.client = http.Client());

    // The sign-in panel (wordmark, form, passkey/Google/guest options, mode links) is taller
    // than the default test surface; later links like "Forgot password?" need to actually be
    // on screen for tap() to land on them rather than silently missing.
    Future<void> open(WidgetTester t) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(home: SignInScreen(config: _noGoogleConfig)));
    }

    testWidgets('checks the email before contacting the server', (t) async {
      await open(t);
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('sign-up requires a longer password', (t) async {
      await open(t);
      await t.tap(find.text('New here? Create a free account'));
      await t.pump();
      await t.enterText(find.widgetWithText(TextField, 'Email'), 'ade@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'short');
      await t.tap(find.text('18 or over'));
      await t.tap(find.byType(Checkbox));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pump();
      expect(find.text('Choose a longer password -- at least 8 characters.'), findsOneWidget);
    });

    testWidgets('sign-up asks for a username and checks it', (t) async {
      await open(t);
      await t.tap(find.text('New here? Create a free account'));
      await t.pump();
      expect(find.text('Create your account'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Email'), 'ade@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Username (optional)'), 'no spaces!');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
      await t.tap(find.text('18 or over'));
      await t.tap(find.byType(Checkbox));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pump();
      expect(find.text('Usernames are 3–20 letters, numbers or underscores.'), findsOneWidget);
    });

    testWidgets('sign-up requires agreeing to the Terms and Privacy Policy', (t) async {
      await open(t);
      await t.tap(find.text('New here? Create a free account'));
      await t.pump();
      await t.enterText(find.widgetWithText(TextField, 'Email'), 'ade@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create account')).onPressed, isNull);
    });

    testWidgets('sign-up asks for an age range, and under-13 needs a guardian email', (t) async {
      await open(t);
      await t.tap(find.text('New here? Create a free account'));
      await t.pump();
      expect(find.widgetWithText(TextField, "Parent or guardian's email"), findsNothing);

      await t.enterText(find.widgetWithText(TextField, 'Email'), 'ade@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
      await t.tap(find.byType(Checkbox));
      await t.pump();
      // No age range picked yet -- the button stays off, same as an unticked terms box.
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create account')).onPressed, isNull);

      await t.tap(find.text('Under 13'));
      await t.pump();
      expect(find.widgetWithText(TextField, "Parent or guardian's email"), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pump();
      expect(find.text("Enter a parent or guardian's email."), findsOneWidget);
    });

    testWidgets('checks a username against the server as you type', (t) async {
      Api.client = MockClient((request) async {
        final username = request.url.queryParameters['username'];
        if (username == 'admin') {
          return http.Response(jsonEncode({'available': false, 'reason': 'blocked'}), 200);
        }
        return http.Response(
          jsonEncode({'available': false, 'reason': 'taken', 'suggestion': '${username}23'}),
          200,
        );
      });
      await open(t);
      await t.tap(find.text('New here? Create a free account'));
      await t.pump();
      await t.enterText(find.widgetWithText(TextField, 'Username (optional)'), 'akin_chess');
      await t.pump();
      expect(find.text('Checking…'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600)); // fires the debounce timer and the request
      expect(find.text('akin_chess is taken. Try akin_chess23.'), findsOneWidget);

      await t.enterText(find.widgetWithText(TextField, 'Email'), 'ade@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
      await t.tap(find.text('18 or over'));
      await t.tap(find.byType(Checkbox));
      await t.pump();
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create account')).onPressed, isNull);
    });

    testWidgets('forgot password hides the password field', (t) async {
      await open(t);
      await t.tap(find.text('Forgot password?'));
      await t.pump();
      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsNothing);
      await t.tap(find.text('Back to sign in'));
      await t.pump();
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('offers continuing as a guest, except on the forgot-password screen', (t) async {
      await open(t);
      expect(find.text('Play as guest'), findsOneWidget);

      await t.tap(find.text('Forgot password?'));
      await t.pump();
      expect(find.text('Play as guest'), findsNothing);
    });

    testWidgets('offers passkey sign-in only on the sign-in screen, not sign-up or reset', (t) async {
      await open(t);
      expect(find.text('Sign in with a passkey'), findsOneWidget);

      await t.tap(find.text('New here? Create a free account'));
      await t.pump();
      expect(find.text('Sign in with a passkey'), findsNothing);

      await t.tap(find.text('Back to sign in'));
      await t.pump();
      await t.tap(find.text('Forgot password?'));
      await t.pump();
      expect(find.text('Sign in with a passkey'), findsNothing);
    });

    testWidgets('Google sign-in is hidden until the server configures a web client id', (t) async {
      await open(t); // _noGoogleConfig has no googleWebClientId
      expect(find.text('Continue with Google'), findsNothing);

      final withGoogle = AppConfig(const {
        'supabase': {'url': 'https://x.supabase.co', 'anonKey': 'x'},
        'googleWebClientId': '123-abc.apps.googleusercontent.com',
      });
      await t.pumpWidget(MaterialApp(home: SignInScreen(config: withGoogle)));
      expect(find.text('Continue with Google'), findsOneWidget);

      // Not offered on the "forgot password" screen (there's no account to link yet).
      await t.tap(find.text('Forgot password?'));
      await t.pump();
      expect(find.text('Continue with Google'), findsNothing);
    });
  });
}
