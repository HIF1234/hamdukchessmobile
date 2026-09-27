import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/auth/sign_in_screen.dart';
import 'package:hamduk_chess/core/links.dart';

void main() {
  group('challenge links', () {
    const id = '1c8864bb-e639-4a3a-8b90-d49a112c50a6';

    test('a real challenge link gives its id', () {
      expect(challengeIdFrom(Uri.parse('https://play.chess.hamduk.com.ng/challenge/$id')), id);
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
    Future<void> open(WidgetTester t) => t.pumpWidget(const MaterialApp(home: SignInScreen()));

    testWidgets('checks the email and password before contacting the server', (t) async {
      await open(t);
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pump();
      expect(find.text('Enter your email address.'), findsOneWidget);

      await t.enterText(find.widgetWithText(TextField, 'Email'), 'ade@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Password'), '123');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pump();
      expect(find.text('Passwords are at least 6 characters.'), findsOneWidget);
    });

    testWidgets('sign-up asks for a username and checks it', (t) async {
      await open(t);
      await t.tap(find.text('New here? Create a free account'));
      await t.pump();
      expect(find.text('Create your account'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Email'), 'ade@example.com');
      await t.enterText(find.widgetWithText(TextField, 'Username (optional)'), 'no spaces!');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pump();
      expect(find.text('Usernames are 3–20 letters, numbers or underscores.'), findsOneWidget);
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
  });
}
