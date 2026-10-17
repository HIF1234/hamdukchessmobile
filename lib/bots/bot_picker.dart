import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import 'bot_game_screen.dart';

/// "Play from a position": from analysis (the review board) or a finished lesson. A simple
/// bot picker -- the full colour/clock/assisted sheet lives in PlayScreen for the normal
/// "new game" flow; here the position itself is already the point, so this just asks which
/// bot, tier-gated the same way, and launches straight in.
Future<void> playBotFromPosition(BuildContext context, {required String fen, required bool playWhite}) async {
  final bots = AppConfig.current?.bots ?? const [];
  if (bots.isEmpty) return;
  final store = await JsonStore.open();
  final tier = (await store.read('me_tier')) as String? ?? 'free';
  if (!context.mounted) return;

  final chosen = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final hc = ctx.hc;
      return SafeArea(
        child: SizedBox(
          height: 420,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: HcSpace.s3),
            children: [
              for (final b in bots)
                HcListRow(
                  leading: HcAvatar(name: b['name'] as String, stage: hcStageFor(b['rating'] as num)),
                  title: b['name'] as String,
                  subtitle: '${b['hometown']} · ${hcNumber((b['rating'] as num).toInt())}',
                  trailing: b['tier'] == 'plus' && tier == 'free' ? Icon(Icons.lock_rounded, color: hc.ink3) : null,
                  onTap: b['tier'] == 'plus' && tier == 'free' ? null : () => Navigator.pop(ctx, b),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (chosen == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BotGameScreen(bot: chosen, playWhite: playWhite, startFen: fen, assistedMode: AppSettings.instance.assistedMode),
  ));
}
