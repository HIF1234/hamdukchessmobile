import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'core/links.dart';
import 'games/challenge_screens.dart';
import 'games/play_screen.dart';
import 'profile/profile_screen.dart';
import 'puzzles/puzzles_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.config});
  final AppConfig config;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  StreamSubscription<String>? _links;

  @override
  void initState() {
    super.initState();
    // Challenge links: open now, including one that arrived before sign-in.
    _links = IncomingLinks.instance.challenges.listen(_openChallenge);
    final pending = IncomingLinks.instance.takePending();
    if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openChallenge(pending));
  }

  void _openChallenge(String id) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChallengeAcceptScreen(challengeId: id)));
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const PuzzlesScreen(),
      PlayScreen(config: widget.config),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.extension_outlined), label: 'Puzzles'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), label: 'Play'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
