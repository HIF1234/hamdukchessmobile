import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';

import '../board/chess_board.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'game_state.dart';

/// Must match _ShareCard's own Container size exactly.
const _shareCardSize = Size(1080, 1920);

/// Must match _GifFrame's own Container size exactly.
const _gifFrameSize = Size(480, 540);

/// Renders [child] with its own isolated render pipeline (ScreenshotController's approach,
/// not the real widget tree: no Overlay insertion, no waiting on a real frame, so this
/// works identically under test and in the app). [context] is only for inheriting the
/// active theme (dark/light). [size] must match [child]'s own fixed size exactly -- without
/// it, the render view falls back to the ambient window size (e.g. the phone screen, or
/// flutter test's default 800x600), clamping and overflowing a card bigger than that.
Future<ui.Image> _captureOffscreen(BuildContext context, Widget child, Size size) {
  return ScreenshotController.widgetToUiImage(child, context: context, targetSize: size, delay: Duration.zero);
}

/// A branded card -- logo, both names with flag and rating, the final position, and the
/// result -- captured as a PNG sized for WhatsApp Status (1080×1920, 9:16). No design spec
/// exists for this yet; sized and laid out to match the app's own tokens as closely as a
/// fixed-pixel export canvas reasonably can.
Future<Uint8List?> captureShareImage(
  BuildContext context, {
  required GameState g,
  required bool whiteAtBottom,
  required String headline,
  required String detail,
}) async {
  final image = await _captureOffscreen(
    context,
    _ShareCard(g: g, whiteAtBottom: whiteAtBottom, headline: headline, detail: detail),
    _shareCardSize,
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// An animated GIF of the whole game, one frame per move, each shown as "N. san". Long
/// games are sampled down to at most 40 frames so this doesn't take forever to build.
/// [onProgress] reports 0.0-1.0 for a progress indicator while it works.
Future<Uint8List?> captureShareGif(
  BuildContext context, {
  required GameState g,
  required bool whiteAtBottom,
  void Function(double progress)? onProgress,
}) async {
  final sanMoves = g.sanMoves;
  final total = sanMoves.length;
  if (total == 0) return null;
  const maxFrames = 40;
  final plies = total <= maxFrames
      ? List.generate(total, (i) => i)
      : List.generate(maxFrames, (i) => (i * (total - 1) / (maxFrames - 1)).round());

  final encoder = img.GifEncoder(repeat: 0);
  for (var i = 0; i < plies.length; i++) {
    if (!context.mounted) return null; // the screen was left mid-build
    final ply = plies[i];
    final fen = g.fenAtPly(ply);
    final frame = await _captureOffscreen(
      context,
      _GifFrame(fen: fen, whiteAtBottom: whiteAtBottom, moveNumber: ply + 1, san: sanMoves[ply]),
      _gifFrameSize,
    );
    final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
    final decoded = bytes == null ? null : img.decodePng(bytes.buffer.asUint8List());
    if (decoded != null) {
      // Hold the final position longer than the moves flashing past.
      final isLast = i == plies.length - 1;
      encoder.addFrame(decoded, duration: isLast ? 250 : 60);
    }
    onProgress?.call((i + 1) / plies.length);
  }
  return encoder.finish();
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.g, required this.whiteAtBottom, required this.headline, required this.detail});
  final GameState g;
  final bool whiteAtBottom;
  final String headline;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final top = whiteAtBottom ? g.black : g.white;
    final bottom = whiteAtBottom ? g.white : g.black;
    return Container(
      width: _shareCardSize.width,
      height: _shareCardSize.height,
      color: hc.bg,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/branding/logo.png', width: 110, height: 110),
        const SizedBox(height: 20),
        Text('Hamduk Chess', style: HcText.displayXl.copyWith(color: hc.ink, fontSize: 54)),
        const SizedBox(height: 56),
        _NameRow(player: top, hc: hc),
        const SizedBox(height: 28),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 920,
            height: 920,
            child: ChessBoardView(fen: g.fen, whiteAtBottom: whiteAtBottom, animate: false),
          ),
        ),
        const SizedBox(height: 28),
        _NameRow(player: bottom, hc: hc),
        const SizedBox(height: 64),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(headline, textAlign: TextAlign.center, style: HcText.displayXl.copyWith(color: hc.ink, fontSize: 58)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(detail, textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2, fontSize: 32)),
        ),
        const SizedBox(height: 40),
        Text('play.chess.hamduk.com.ng', style: HcText.bodySm.copyWith(color: hc.ink3, fontSize: 26)),
      ]),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.player, required this.hc});
  final Player player;
  final HcPalette hc;

  @override
  Widget build(BuildContext context) {
    final flag = countryFlagEmoji(player.country);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (flag != null) ...[Text(flag, style: const TextStyle(fontSize: 34)), const SizedBox(width: 14)],
      Text(player.username, style: HcText.titleSm.copyWith(color: hc.ink, fontSize: 38, fontWeight: FontWeight.w700)),
      if (player.rating != null) ...[
        const SizedBox(width: 14),
        Text('${player.rating}', style: HcText.bodySm.copyWith(color: hc.ink2, fontSize: 34)),
      ],
    ]);
  }
}

/// One GIF frame: the board plus a small "N. san" caption, kept compact since it's repeated
/// dozens of times and the file size adds up.
class _GifFrame extends StatelessWidget {
  const _GifFrame({required this.fen, required this.whiteAtBottom, required this.moveNumber, required this.san});
  final String fen;
  final bool whiteAtBottom;
  final int moveNumber;
  final String san;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Container(
      width: _gifFrameSize.width,
      height: _gifFrameSize.height,
      color: hc.bg,
      child: Column(children: [
        SizedBox(width: 480, height: 480, child: ChessBoardView(fen: fen, whiteAtBottom: whiteAtBottom, animate: false)),
        Expanded(
          child: Center(
            child: Text('$moveNumber. $san', style: HcText.titleSm.copyWith(color: hc.ink, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
