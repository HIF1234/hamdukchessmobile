import 'dart:async';

import 'package:app_links/app_links.dart';

/// Links that open the app (spec §8: WhatsApp challenge links go straight to the game).
/// Only `https://play.chess.hamduk.com.ng/challenge/{id}` is handled today.
class IncomingLinks {
  IncomingLinks._();
  static final instance = IncomingLinks._();

  final _challenges = StreamController<String>.broadcast();
  final _games = StreamController<String>.broadcast();
  String? _pending; // arrived before the app could show it (e.g. while signed out)
  String? _pendingGame;
  Uri? _last;
  DateTime _lastAt = DateTime(0);

  /// Challenge ids to open.
  Stream<String> get challenges => _challenges.stream;

  /// Game ids to open (from tapped notifications such as "Your move").
  Stream<String> get games => _games.stream;

  String? takePendingGame() {
    final p = _pendingGame;
    _pendingGame = null;
    return p;
  }

  /// A site path such as "/play/{id}" from a notification.
  void openPath(String path) => handle(Uri.parse('https://play.chess.hamduk.com.ng$path'));

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
    if (initial != null) handle(initial);
    links.uriLinkStream.listen(handle);
  }

  void handle(Uri uri) {
    final now = DateTime.now();
    if (uri == _last && now.difference(_lastAt) < const Duration(seconds: 5)) return;
    _last = uri;
    _lastAt = now;
    final game = gameIdFrom(uri);
    if (game != null) {
      if (_games.hasListener) {
        _games.add(game);
      } else {
        _pendingGame = game;
      }
      return;
    }
    final id = challengeIdFrom(uri);
    if (id == null) return;
    if (_challenges.hasListener) {
      _challenges.add(id);
    } else {
      _pending = id;
    }
  }
}

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

String? _idAfter(Uri uri, String section) {
  if (uri.host != 'play.chess.hamduk.com.ng') return null;
  final seg = uri.pathSegments;
  if (seg.length != 2 || seg[0] != section) return null;
  return _uuid.hasMatch(seg[1]) ? seg[1] : null;
}

/// The challenge id in a challenge link, or null if it isn't one.
String? challengeIdFrom(Uri uri) => _idAfter(uri, 'challenge');

/// The game id in a game link (/play/{id}), or null if it isn't one.
String? gameIdFrom(Uri uri) => _idAfter(uri, 'play');

final _username = RegExp(r'^[a-z0-9_]{3,20}$');

/// The username in a profile link (/profile/{username}), or null if it isn't one -- for the
/// "scan to add as friend" QR code.
String? profileUsernameFrom(Uri uri) {
  if (uri.host != 'play.chess.hamduk.com.ng') return null;
  final seg = uri.pathSegments;
  if (seg.length != 2 || seg[0] != 'profile') return null;
  return _username.hasMatch(seg[1]) ? seg[1] : null;
}
