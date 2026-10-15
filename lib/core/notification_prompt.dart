import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'push.dart';
import 'storage.dart';

/// Asks for notification permission after the first finished game, not at launch, with a
/// one-line reason -- the OS prompt itself is triggered by [Push.start] once the player
/// agrees here, or never if notification permission was already decided some other way
/// (see home_shell.dart's own launch-time check).
class NotificationPrompt {
  static const _key = 'notification_prompt_asked';

  static Future<void> gameFinished(BuildContext context) async {
    final store = await JsonStore.open();
    if (await store.read(_key) == true) return;
    await store.write(_key, true); // ask at most once, regardless of the outcome below

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.notDetermined || !context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn on notifications?'),
        content: const Text(
          "We'll tell you when it's your move, when a friend challenges you and when the daily puzzle is ready.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn on')),
        ],
      ),
    );
    if (ok == true) await Push.start();
  }
}
