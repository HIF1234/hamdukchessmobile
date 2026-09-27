import 'dart:async';

import 'package:app_links/app_links.dart';

/// Links that open the app (spec §8: WhatsApp challenge links go straight to the game).
/// Only `https://play.chess.hamduk.com.ng/challenge/{id}` is handled today.
class IncomingLinks {
  IncomingLinks._();
  static final instance = IncomingLinks._();

  final _challenges = StreamController<String>.broadcast();
  String? _pending; // arrived before the app could show it (e.g. while signed out)
  Uri? _last;
  DateTime _lastAt = DateTime(0);

  /// Challenge ids to open.
  Stream<String> get challenges => _challenges.stream;

  /// A challenge that arrived while nothing was listening; cleared once taken.
  String? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }

  Future<void> start() async {
    final links = AppLinks();
    // The launch link and later links can both arrive on the stream and via getInitialLink;
    // the same link within a few seconds is handled once.
    final initial = await links.getInitialLink();
    if (initial != null) _handle(initial);
    links.uriLinkStream.listen(_handle);
  }

  void _handle(Uri uri) {
    final now = DateTime.now();
    if (uri == _last && now.difference(_lastAt) < const Duration(seconds: 5)) return;
    _last = uri;
    _lastAt = now;
    final id = challengeIdFrom(uri);
    if (id == null) return;
    if (_challenges.hasListener) {
      _challenges.add(id);
    } else {
      _pending = id;
    }
  }
}

/// The challenge id in a challenge link, or null if it isn't one.
String? challengeIdFrom(Uri uri) {
  if (uri.host != 'play.chess.hamduk.com.ng') return null;
  final seg = uri.pathSegments;
  if (seg.length != 2 || seg[0] != 'challenge') return null;
  final id = seg[1];
  return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(id) ? id : null;
}
