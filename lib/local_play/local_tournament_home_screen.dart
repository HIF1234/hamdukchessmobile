import 'package:flutter/material.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'host_screen.dart';
import 'join_screen.dart';

/// Entry point for data-free local tournaments: two phones on one WiFi hotspot, no internet,
/// no mobile data, nothing synced to the server afterwards (casual only).
class LocalTournamentHomeScreen extends StatelessWidget {
  const LocalTournamentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Local tournament')),
      body: Padding(
        padding: const EdgeInsets.all(HcSpace.s5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.wifi_tethering_rounded, size: 48, color: hc.green),
          const SizedBox(height: HcSpace.s3),
          Text('Play without data', style: HcText.displayMd.copyWith(color: hc.ink)),
          const SizedBox(height: HcSpace.s2),
          Text(
            'One phone shares its WiFi hotspot; everyone else joins that network and connects '
            'to play. No internet or mobile data needed for anyone once you\'re set up. These '
            'games are casual -- they don\'t affect your rating or sync anywhere.',
            style: HcText.body.copyWith(color: hc.ink2),
          ),
          const SizedBox(height: HcSpace.s7),
          HcListGroup(children: [
            HcListRow(
              leading: Icon(Icons.wifi_tethering_rounded, color: hc.ink2),
              title: "I'm hosting",
              subtitle: 'Share your hotspot and run the tournament',
              trailing: Icon(Icons.chevron_right_rounded, color: hc.ink3),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HostLocalTournamentScreen())),
            ),
            HcListRow(
              leading: Icon(Icons.qr_code_scanner_rounded, color: hc.ink2),
              title: "I'm joining",
              subtitle: "Scan the host's code to connect",
              trailing: Icon(Icons.chevron_right_rounded, color: hc.ink3),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinLocalTournamentScreen())),
            ),
          ]),
        ]),
      ),
    );
  }
}
