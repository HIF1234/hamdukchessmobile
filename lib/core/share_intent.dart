import 'dart:async';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// "Import a game" from another app's share sheet (e.g. a .pgn shared from WhatsApp).
/// Android only -- iOS needs a real Share Extension Xcode target, not built.
class ShareIntentListener {
  ShareIntentListener._();
  static final instance = ShareIntentListener._();

  final _games = StreamController<String>.broadcast();
  String? _pending; // arrived before the app could show it (e.g. while signed out)

  /// PGN/FEN text to hand to ImportGameScreen.
  Stream<String> get games => _games.stream;

  /// Text that arrived before anything was listening; cleared once taken.
  String? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }

  Future<void> start() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) await _handle(initial);
    ReceiveSharingIntent.instance.getMediaStream().listen(_handle);
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    final file = files.first;
    String? text;
    if (file.type == SharedMediaType.text) {
      text = file.path;
    } else {
      try {
        text = await File(file.path).readAsString();
      } catch (_) {
        text = null;
      }
    }
    ReceiveSharingIntent.instance.reset();
    if (text == null || text.trim().isEmpty) return;
    if (_games.hasListener) {
      _games.add(text);
    } else {
      _pending = text;
    }
  }
}
