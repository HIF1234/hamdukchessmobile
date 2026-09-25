import 'package:flutter/material.dart';

import 'core/app_config.dart';
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
      _PlayPlaceholder(config: widget.config),
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

/// Bots and online play come in the next build; this lists the bots the app already knows.
class _PlayPlaceholder extends StatelessWidget {
  const _PlayPlaceholder({required this.config});
  final AppConfig config;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Play', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Online games and the Naija bots are coming in the next build.'),
          const SizedBox(height: 16),
          for (final b in config.bots)
            ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(b['portraitUrl'] as String)),
              title: Text(b['name'] as String),
              subtitle: Text('${b['hometown']} · ${b['catchphrase']}'),
              trailing: Text('${b['rating']}'),
            ),
        ],
      );
}
