import 'package:flutter/material.dart';

import '../board/chess_board.dart';
import '../bots/bot_picker.dart';
import '../core/api.dart';

/// Plays through one tutorial's steps: "observe" positions just need Next, "move" positions
/// require the player to find the right move before advancing. Data comes from GET
/// /tutorials/{id}'s shape (kind, fen, title, body, answer?, hint?) -- same step format the
/// website uses, rendered on the app's own board widget.
///
/// Progress syncs with the website via GET/POST /tutorials/progress (same table the
/// website's own lesson player writes to): resumes at the saved step unless the tutorial
/// was already completed, same as web.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.tutorial});
  final Map<String, dynamic> tutorial;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final List<Map<String, dynamic>> _steps = (widget.tutorial['steps'] as List).cast<Map<String, dynamic>>();
  int _i = 0;
  bool _loaded = false;
  bool _solved = false;
  bool _showHint = false;
  String? _wrongMove;
  int _lastSavedStep = -1;

  Map<String, dynamic> get _step => _steps[_i];
  bool get _isMove => _step['kind'] == 'move';
  String get _tutorialId => widget.tutorial['id'] as String;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    var startAt = 0;
    try {
      final progress = (await Api.instance.get('/tutorials/progress') as List).cast<Map<String, dynamic>>();
      Map<String, dynamic>? existing;
      for (final p in progress) {
        if (p['tutorial_id'] == _tutorialId) {
          existing = p;
          break;
        }
      }
      if (existing != null && existing['completed'] != true) {
        startAt = ((existing['step_index'] as num?)?.toInt() ?? 0).clamp(0, _steps.length - 1);
      }
    } on ApiError {
      // Best-effort; starting from the beginning is fine without known progress.
    }
    if (!mounted) return;
    setState(() {
      _i = startAt;
      _loaded = true;
    });
    _persistStep(_i);
  }

  void _persistStep(int index) {
    if (_lastSavedStep == index) return;
    _lastSavedStep = index;
    Api.instance.post('/tutorials/progress', {'tutorial_id': _tutorialId, 'step_index': index, 'completed': false}).catchError((_) => null);
  }

  void _persistComplete() {
    Api.instance.post('/tutorials/progress', {
      'tutorial_id': _tutorialId,
      'step_index': _steps.length - 1,
      'completed': true,
    }).catchError((_) => null);
  }

  void _next() {
    if (_i >= _steps.length - 1) {
      _persistComplete();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _i++;
      _solved = false;
      _showHint = false;
      _wrongMove = null;
    });
    _persistStep(_i);
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
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tutorial['title'] as String)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
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
