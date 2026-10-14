import 'package:flutter/material.dart';

import 'hc_widgets.dart';
import 'storage.dart';
import 'theme.dart';

/// The three biggest changes for each released version. Add an entry here when cutting a
/// release; the sheet below shows the newest entry once per version, after an update.
const Map<String, List<String>> _releaseNotes = {
  '1.0.0': [
    'Sign in with a passkey -- your face, fingerprint or a security key, no password.',
    'Play as a guest, no account needed to try it out.',
    'A fresh look across every screen.',
  ],
};

/// Shows a "what's new" sheet once per version, after an update (never on a fresh install).
/// Call from the home shell once it's mounted.
Future<void> maybeShowWhatsNew(BuildContext context, String currentVersion) async {
  final notes = _releaseNotes[currentVersion];
  if (notes == null) return;
  final store = await JsonStore.open();
  const key = 'whats_new_last_seen_version';
  final lastSeen = await store.read(key) as String?;
  await store.write(key, currentVersion);
  // A fresh install has no lastSeen at all; don't greet a brand-new player with "what's new".
  if (lastSeen == null || lastSeen == currentVersion || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final hc = ctx.hc;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HcSpace.s5, HcSpace.s5, HcSpace.s5, HcSpace.s5),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text("What's new", style: HcText.displayMd.copyWith(color: hc.ink)),
            const SizedBox(height: HcSpace.s4),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: HcSpace.s3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 6, color: hc.green),
                  const SizedBox(width: HcSpace.s3),
                  Expanded(child: Text(n, style: HcText.body.copyWith(color: hc.ink2))),
                ]),
              ),
            const SizedBox(height: HcSpace.s2),
            FilledButton(style: HcButtons.large(), onPressed: () => Navigator.of(ctx).pop(), child: const Text('Got it')),
          ]),
        ),
      );
    },
  );
}
