import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../games/challenge_screens.dart';
import '../profile/public_profile_screen.dart';
import 'links.dart';

/// Scan someone's challenge QR to start the game, or their profile QR to add them as a
/// friend -- both are the same https://play.chess.hamduk.com.ng links the app already
/// opens from WhatsApp, just read off a screen instead of tapped.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final challengeId = challengeIdFrom(uri);
    final username = profileUsernameFrom(uri);
    if (challengeId == null && username == null) return;
    setState(() => _scanned = true);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => challengeId != null
          ? ChallengeAcceptScreen(challengeId: challengeId)
          : PublicProfileScreen(username: username!),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan a QR code')),
        body: Stack(children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Text(
              "Scan a friend's challenge or profile QR code",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4)]),
            ),
          ),
        ]),
      );
}
