import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../board/voice_move.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'game_controller.dart';

/// "Say move aloud" (design/board.md has no spec for this yet -- it's a new, standalone
/// sheet rather than a board overlay). Records a short clip, sends it for transcription,
/// and plays the result if [parseVoiceMove] can resolve it against the current position.
class VoiceMoveSheet extends StatefulWidget {
  const VoiceMoveSheet({super.key, required this.controller});
  final GameController controller;

  @override
  State<VoiceMoveSheet> createState() => _VoiceMoveSheetState();
}

enum _VoiceState { idle, recording, transcribing }

class _VoiceMoveSheetState extends State<VoiceMoveSheet> {
  final _recorder = AudioRecorder();
  _VoiceState _state = _VoiceState.idle;
  String? _error;
  String? _heard;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_state == _VoiceState.recording) {
      await _stopAndTranscribe();
      return;
    }
    if (_state == _VoiceState.transcribing) return;
    setState(() {
      _error = null;
      _heard = null;
    });
    if (!await _recorder.hasPermission()) {
      setState(() => _error = 'Microphone permission is needed to say a move.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice-move-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (mounted) setState(() => _state = _VoiceState.recording);
  }

  Future<void> _stopAndTranscribe() async {
    final path = await _recorder.stop();
    if (mounted) setState(() => _state = _VoiceState.transcribing);
    try {
      if (path == null) throw Exception('No recording produced');
      final file = File(path);
      final bytes = await file.readAsBytes();
      unawaited(file.delete());
      final text = await widget.controller.transcribeVoiceMove(base64Encode(bytes));
      final move = parseVoiceMove(text, widget.controller.boardFen);
      if (!move.ok) {
        _fail(move.error ?? "Didn't catch a move.", heard: text);
        return;
      }
      final played = widget.controller.play(move.from!, move.to!, move.promotion);
      if (!mounted) return;
      if (played) {
        Navigator.of(context).pop();
      } else {
        _fail("That move isn't legal right now.", heard: text);
      }
    } on ApiError catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail("Couldn't record audio.");
    }
  }

  void _fail(String error, {String? heard}) {
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.idle;
      _error = error;
      _heard = heard;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final recording = _state == _VoiceState.recording;
    final bg = recording ? hc.dangerInk : hc.green;
    final fg = recording ? hc.onDanger : hc.onGreen;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(HcSpace.s6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Say your move', style: HcText.titleMd.copyWith(color: hc.ink)),
          const SizedBox(height: HcSpace.s2),
          Text(
            switch (_state) {
              _VoiceState.idle => 'Tap and say a move, like "knight f3" or "e2 to e4".',
              _VoiceState.recording => 'Listening… tap to stop.',
              _VoiceState.transcribing => 'Thinking…',
            },
            textAlign: TextAlign.center,
            style: HcText.bodySm.copyWith(color: hc.ink2),
          ),
          const SizedBox(height: HcSpace.s4),
          GestureDetector(
            onTap: _tap,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
              child: _state == _VoiceState.transcribing
                  ? Padding(padding: const EdgeInsets.all(28), child: CircularProgressIndicator(color: fg))
                  : Icon(recording ? Icons.stop_rounded : Icons.mic_rounded, color: fg, size: 36),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: HcSpace.s4),
            if (_heard != null) Text('Heard: "$_heard"', style: HcText.bodySm.copyWith(color: hc.ink3)),
            Text(_error!, textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
          ],
        ]),
      ),
    );
  }
}
