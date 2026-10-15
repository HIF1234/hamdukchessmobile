import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/onboarding/onboarding_screen.dart';

void main() {
  // _finish() (reached only by tapping a level) writes to JsonStore, which needs a real
  // documents directory -- these tests stop short of that and just cover the step flow.
  Future<void> open(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(home: OnboardingScreen(onDone: (_) {})));
  }

  testWidgets('starts on the language question, then the welcome slides, then level', (t) async {
    await open(t);
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Yoruba'), findsOneWidget);

    await t.tap(find.text('Continue'));
    await t.pump();
    expect(find.text('Chess, built for Africa'), findsOneWidget);

    await t.tap(find.text('Skip'));
    await t.pump();
    expect(find.text('How well do you play?'), findsOneWidget);
    expect(find.text('New to chess'), findsOneWidget);
    expect(find.text('Tournament player'), findsOneWidget);
  });

  testWidgets('Next moves through both welcome slides before reaching level', (t) async {
    await open(t);
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(find.text('Chess, built for Africa'), findsOneWidget);

    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('Play online or offline'), findsOneWidget);

    await t.tap(find.text('Next'));
    await t.pump();
    expect(find.text('How well do you play?'), findsOneWidget);
  });
}
