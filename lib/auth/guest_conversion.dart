import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/hc_widgets.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import 'save_account_screen.dart';

/// Counts games a guest finishes (bot or local-play) so we can offer, once, to save their
/// progress to a real account -- per spec: "After the third game: 'Save your games and
/// rating?' turns the guest into an account, history kept."
class GuestConversion {
  static const _key = 'guest_conversion';

  /// Call right after a guest finishes a bot or local-play game.
  static Future<void> gameFinished(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !user.isAnonymous) return;
    final store = await JsonStore.open();
    final state = (await store.read(_key) as Map?) ?? {};
    if (state['offered'] == true) return;
    final count = (state['count'] as int? ?? 0) + 1;
    await store.write(_key, {'count': count, 'offered': count >= 3});
    if (count != 3 || !context.mounted) return;
    await _showPrompt(context);
  }

  static Future<void> _showPrompt(BuildContext context) async {
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final hc = ctx.hc;
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(color: hc.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(HcRadius.lg))),
            padding: const EdgeInsets.fromLTRB(HcSpace.s5, HcSpace.s6, HcSpace.s5, HcSpace.s6),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Save your games and rating?', style: HcText.displayMd.copyWith(color: hc.ink)),
              const SizedBox(height: HcSpace.s2),
              Text(
                "Turn your guest play into an account and keep everything you've done so far -- nothing is lost.",
                style: HcText.body.copyWith(color: hc.ink2),
              ),
              const SizedBox(height: HcSpace.s5),
              FilledButton(
                style: HcButtons.large(),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save my account'),
              ),
              const SizedBox(height: HcSpace.s2),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            ]),
          ),
        );
      },
    );
    if (save == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SaveAccountScreen()));
    }
  }
}
