import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../bots/bot_picker.dart';

/// Plays through one tutorial's steps: "observe" positions just need Next, "move" positions
/// require the player to find the right move before advancing. Data comes from GET
/// /tutorials/{id}'s shape (kind, fen, title, body, answer?, hint?) -- same step format the
/// website uses, rendered on the app's own board widget.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.tutorial});
  final Map<String, dynamic> tutorial;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final List<Map<String, dynamic>> _steps = (widget.tutorial['steps'] as List).cast<Map<String, dynamic>>();
  int _i = 0;
  bool _solved = false;
  bool _showHint = false;
  String? _wrongMove;

  Map<String, dynamic> get _step => _steps[_i];
  bool get _isMove => _step['kind'] == 'move';

  void _next() {
    if (_i >= _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _i++;
      _solved = false;
      _showHint = false;
      _wrongMove = null;
    });
  }

  bool _onMove(String from, String to, String? promo) {
    final answer = _step['answer'] as String;
    final tried = '$from$to${promo ?? ''}';
    if (tried == answer || '$from$to' == answer) {
      setState(() => _solved = true);
      return true;
    }
    setState(() => _wrongMove = tried);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _wrongMove = null);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final step = _step;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tutorial['title'] as String),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_i + 1) / _steps.length),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ChessBoardView(
                key: ValueKey('$_i-${step['fen']}'),
                fen: step['fen'] as String,
                onMove: _isMove && !_solved ? _onMove : null,
                hintSquare: _showHint && _isMove ? (step['hint'] as String? ?? (step['answer'] as String).substring(0, 2)) : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(step['title'] as String, style: t.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(step['body'] as String, style: t.textTheme.bodyMedium),
          if (_wrongMove != null) ...[
            const SizedBox(height: 8),
            Text('Not quite -- try again.', style: TextStyle(color: t.colorScheme.error)),
          ],
          if (_solved) ...[
            const SizedBox(height: 8),
            Text('Correct!', style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 20),
          if (_i >= _steps.length - 1 && (!_isMove || _solved))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => playBotFromPosition(
                  context,
                  fen: step['fen'] as String,
                  playWhite: (step['fen'] as String).split(' ')[1] == 'w',
                ),
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('Play it out vs a bot'),
              ),
            ),
          Row(children: [
            if (_isMove && !_solved)
              TextButton(onPressed: () => setState(() => _showHint = true), child: const Text('Hint')),
            const Spacer(),
            if (!_isMove || _solved)
              FilledButton(
                onPressed: _next,
                child: Text(_i >= _steps.length - 1 ? 'Finish' : 'Next'),
              ),
          ]),
        ],
      ),
    );
  }
}
