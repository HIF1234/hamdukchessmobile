import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hc_widgets.dart';
import 'theme.dart';

const _playStoreUrl = 'https://play.google.com/store/apps/details?id=ng.com.hamduk.chess';

/// Full-screen block shown when the installed app is older than the server's required
/// version. There is no way past this screen except updating.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HcColors.forest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HcSpace.s6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_rounded, size: 56, color: HcColors.brandGold),
              const SizedBox(height: HcSpace.s4),
              Text('Update Hamduk Chess', style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
              const SizedBox(height: HcSpace.s2),
              Text(
                'This version is too old to keep playing. Update to continue.',
                style: HcText.body.copyWith(color: HcColors.onForest2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HcSpace.s6),
              FilledButton(
                style: HcButtons.large(),
                onPressed: () => launchUrl(Uri.parse(_playStoreUrl), mode: LaunchMode.externalApplication),
                child: const Text('Update now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
