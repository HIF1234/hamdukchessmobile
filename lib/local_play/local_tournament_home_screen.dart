import 'package:flutter/material.dart';

import 'host_screen.dart';
import 'join_screen.dart';

/// Entry point for data-free local tournaments: two phones on one WiFi hotspot, no internet,
/// no mobile data, nothing synced to the server afterwards (casual only).
class LocalTournamentHomeScreen extends StatelessWidget {
  const LocalTournamentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Local tournament')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.wifi_tethering, size: 48, color: t.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Play without data', style: t.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'One phone shares its WiFi hotspot; everyone else joins that network and connects '
            'to play. No internet or mobile data needed for anyone once you\'re set up. These '
            'games are casual -- they don\'t affect your rating or sync anywhere.',
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: const Text("I'm hosting"),
              subtitle: const Text("Share your hotspot and run the tournament"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HostLocalTournamentScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text("I'm joining"),
              subtitle: const Text("Scan the host's code to connect"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinLocalTournamentScreen())),
            ),
          ),
        ]),
      ),
    );
  }
}
