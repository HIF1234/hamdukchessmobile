import 'package:flutter/material.dart';

import 'core/app_config.dart';
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
