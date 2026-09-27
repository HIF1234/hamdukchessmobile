import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';
import 'links.dart';
import 'telemetry.dart';

/// Phone notifications ("Your move", challenge accepted, anything from the notification bell).
/// The server sends them through Firebase Cloud Messaging to the tokens registered here.
class Push {
  static final _fcm = FirebaseMessaging.instance;
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _opened;

  /// Call once signed in. Asks permission (Android 13+ shows a prompt), registers this phone,
  /// and routes taps on notifications to the right screen.
  static Future<void> start() async {
    try {
      final settings = await _fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _fcm.getToken();
      if (token != null) await _register(token);
      _refresh ??= _fcm.onTokenRefresh.listen(_register);
      _opened ??= FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final first = await _fcm.getInitialMessage(); // the app was launched by a tap
      if (first != null) _open(first);
    } catch (e, st) {
      Telemetry.recordError(e, st, reason: 'push setup');
    }
  }

  static Future<void> _register(String token) async {
    try {
      await Api.instance.post('/devices', {'token': token, 'platform': 'android'});
    } on ApiError {
      // Offline now; it registers again next start or when the token refreshes.
    }
  }

  static void _open(RemoteMessage m) {
    final link = m.data['link'];
    if (link is String && link.startsWith('/')) IncomingLinks.instance.openPath(link);
  }

  /// Call before signing out, so this phone stops getting the player's notifications.
  static Future<void> stop() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await Api.instance.delete('/devices', {'token': token});
      await _fcm.deleteToken();
    } catch (_) {
      // Signing out anyway; the server also drops tokens that stop working.
    }
  }
}
