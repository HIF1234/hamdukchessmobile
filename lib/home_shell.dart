// Supabase's own passkey API is marked @experimental (it's a beta feature on their side,
// not an unstable choice on ours); every call into it trips this lint.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/passkey_auth.dart';
import 'core/app_config.dart';
import 'core/hc_widgets.dart';
import 'core/links.dart';
import 'core/push.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'games/game_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'games/challenge_screens.dart';
import 'games/play_screen.dart';
import 'profile/profile_screen.dart';
import 'puzzles/puzzles_screen.dart';
import 'social/social_screen.dart';
import 'tournaments/tournaments_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.config});
  final AppConfig config;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  StreamSubscription<String>? _links;
  StreamSubscription<String>? _gameLinks;

  @override
  void initState() {
    super.initState();
    // Challenge links: open now, including one that arrived before sign-in.
    _links = IncomingLinks.instance.challenges.listen(_openChallenge);
    final pending = IncomingLinks.instance.takePending();
    if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openChallenge(pending));
    // Tapped notifications ("Your move", challenge accepted) open their game.
    _gameLinks = IncomingLinks.instance.games.listen(_openGame);
    final pendingGame = IncomingLinks.instance.takePendingGame();
    if (pendingGame != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openGame(pendingGame));
    Push.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptPasskey());
  }

  /// Offers to add a passkey once per account, right after a real (non-guest) sign-in, so
  /// "sign in faster next time" lands when it's actually true -- not buried in Settings where
  /// most players will never find it on their own.
  Future<void> _maybePromptPasskey() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final store = await JsonStore.open();
    final key = 'passkey_prompt_asked_${user.id}';
    if (await store.read(key) == true) return;
    await store.write(key, true); // ask at most once per account, regardless of outcome below

    final List<Passkey> existing;
    try {
      existing = await Supabase.instance.client.auth.passkey.list();
    } catch (_) {
      return; // offline, or the server doesn't have passkeys configured; skip quietly
    }
    if (existing.isNotEmpty || !mounted) return;

    final add = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _PasskeyPromptSheet());
    if (add != true || !mounted) return;
    try {
      await PasskeyAuth.register();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Passkey added. You can sign in with it next time.')));
      }
    } catch (e) {
      if (mounted && !PasskeyAuth.isCancellation(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't add a passkey right now. You can try again later in Profile → Settings.")),
        );
      }
    }
  }

  void _openGame(String id) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (!mounted || me == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(gameId: id, myId: me)));
  }

  void _openChallenge(String id) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChallengeAcceptScreen(challengeId: id)));
  }

  @override
  void dispose() {
    _links?.cancel();
    _gameLinks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const PuzzlesScreen(),
      PlayScreen(config: widget.config),
      const TournamentsScreen(),
      const SocialScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.extension_outlined), selectedIcon: Icon(Icons.extension_rounded), label: 'Puzzles'),
          NavigationDestination(icon: KnightIcon(), selectedIcon: KnightIcon(), label: 'Play'),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Tournaments',
          ),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Social'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _PasskeyPromptSheet extends StatelessWidget {
  const _PasskeyPromptSheet();

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HcSpace.s5, HcSpace.s5, HcSpace.s5, HcSpace.s5),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: hc.greenSoft, shape: BoxShape.circle),
              child: Icon(Icons.fingerprint_rounded, color: hc.green, size: 28),
            ),
          ),
          const SizedBox(height: HcSpace.s4),
          Text('Sign in faster next time', style: HcText.displayMd.copyWith(color: hc.ink), textAlign: TextAlign.center),
          const SizedBox(height: HcSpace.s2),
          Text(
            'Add a passkey so you can sign in with your face, fingerprint or a security key — no password to type.',
            style: HcText.body.copyWith(color: hc.ink2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HcSpace.s5),
          FilledButton(
            style: HcButtons.large(),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add a passkey'),
          ),
          const SizedBox(height: HcSpace.s2),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
        ]),
      ),
    );
  }
}
