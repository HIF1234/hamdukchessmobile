import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/hc_widgets.dart';

Future<void> pump(WidgetTester t, PlayerBar bar) =>
    t.pumpWidget(MaterialApp(home: Scaffold(body: bar)));

void main() {
  testWidgets('a real title shows next to the name', (t) async {
    await pump(t, PlayerBar(name: 'Ade', rating: 1500, fideTitle: 'GM', clock: const SizedBox()));
    expect(find.text('GM'), findsOneWidget);
    expect(find.text('Ade'), findsOneWidget);
  });

  testWidgets('an untitled player past 2200 gets the in-house Expert badge', (t) async {
    await pump(t, PlayerBar(name: 'Bola', rating: 2201, clock: const SizedBox()));
    expect(find.text('Expert'), findsOneWidget);
  });

  testWidgets('an untitled player under 2200 gets no badge', (t) async {
    await pump(t, PlayerBar(name: 'Chidi', rating: 2199, clock: const SizedBox()));
    expect(find.text('Expert'), findsNothing);
  });

  testWidgets('a real title beats the in-house badge even past 2200', (t) async {
    await pump(t, PlayerBar(name: 'Dayo', rating: 2400, fideTitle: 'IM', clock: const SizedBox()));
    expect(find.text('IM'), findsOneWidget);
    expect(find.text('Expert'), findsNothing);
  });

  testWidgets('plus and gold show a membership icon, free shows none', (t) async {
    await pump(t, PlayerBar(name: 'Eve', rating: 1500, subscriptionTier: 'gold', clock: const SizedBox()));
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);

    await pump(t, PlayerBar(name: 'Femi', rating: 1500, subscriptionTier: 'plus', clock: const SizedBox()));
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);

    await pump(t, PlayerBar(name: 'Gift', rating: 1500, subscriptionTier: 'free', clock: const SizedBox()));
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });
}
