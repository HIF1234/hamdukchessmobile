import 'package:chess/chess.dart' as ch;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../review/review_screen.dart';
import 'analysis_screen.dart';

/// A FEN has exactly 8 '/'-separated placement ranks; anything else (move numbers, SAN,
/// PGN headers) is treated as PGN.
bool looksLikeFen(String text) {
  final fields = text.trim().split(RegExp(r'\s+'));
  return fields.isNotEmpty && fields.first.split('/').length == 8;
}

/// "Paste PGN or FEN, or open a .pgn file saved on the phone." Detects FEN vs PGN, then
/// opens the right screen: a FEN goes to the Analysis board (a position, no move
/// history); a PGN goes to Game review (a full game). Receiving a file shared directly
/// from another app (e.g. WhatsApp's share sheet) isn't built -- that needs share-intent
/// platform wiring (AndroidManifest intent filters, iOS equivalents), not just a picker;
/// this only covers a .pgn already saved on the phone, chosen through the system picker.
class ImportGameScreen extends StatefulWidget {
  const ImportGameScreen({super.key});

  @override
  State<ImportGameScreen> createState() => _ImportGameScreenState();
}

class _ImportGameScreenState extends State<ImportGameScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _import() => _importText(_controller.text.trim());

  void _importText(String text) {
    if (text.isEmpty) return;
    setState(() => _error = null);

    if (looksLikeFen(text)) {
      try {
        ch.Chess.fromFEN(text, check_validity: true);
      } catch (_) {
        setState(() => _error = 'That FEN looks invalid.');
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnalysisScreen(startFen: text)));
      return;
    }

    final g = ch.Chess();
    if (!g.load_pgn(text)) {
      setState(() => _error = "Couldn't read that as PGN or FEN.");
      return;
    }
    final sanMoves = g.getHistory().cast<String>();
    if (sanMoves.isEmpty) {
      setState(() => _error = 'No moves found in that PGN.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReviewScreen(startFen: standardStartFen, sanMoves: sanMoves, whiteAtBottom: true),
    ));
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pgn']);
      if (file == null) return; // user cancelled
      final text = await file.xFile.readAsString();
      if (!mounted) return;
      _controller.text = text;
      _importText(text.trim());
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't read that file.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Import a game')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HcSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Paste a PGN (a full game, opens in Game review) or a FEN (one position, opens in the Analysis board).',
              style: HcText.bodySm.copyWith(color: hc.ink2),
            ),
            const SizedBox(height: HcSpace.s3),
            TextField(
              controller: _controller,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '1. e4 e5 2. Nf3 ...\nor\nrnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: HcSpace.s2),
                child: Text(_error!, style: HcText.bodySm.copyWith(color: hc.dangerInk)),
              ),
            const SizedBox(height: HcSpace.s3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(style: HcButtons.large(), onPressed: _import, child: const Text('Import')),
            ),
            const SizedBox(height: HcSpace.s2),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open a .pgn file from this phone'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
