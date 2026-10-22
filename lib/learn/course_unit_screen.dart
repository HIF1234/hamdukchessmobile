import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../board/chess_board.dart';
import '../bots/bot_game_screen.dart';
import '../core/api.dart';
import '../core/app_config.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../puzzles/puzzle_session.dart';
import 'certificate_pdf.dart';
import 'tutorial_screen.dart';

/// One course-path unit: lesson, practice puzzles, a short quiz, and a bot to beat. Each
/// part is marked done via POST /course/progress once finished; the unit completes when
/// all four are.
class CourseUnitScreen extends StatefulWidget {
  const CourseUnitScreen({super.key, required this.unit});
  final Map<String, dynamic> unit;

  @override
  State<CourseUnitScreen> createState() => _CourseUnitScreenState();
}

class _CourseUnitScreenState extends State<CourseUnitScreen> {
  Map<String, dynamic>? _progress;
  String? _error;

  String get _unitId => widget.unit['id'] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/course/progress') as Map;
      final list = (r['progress'] as List).cast<Map<String, dynamic>>();
      Map<String, dynamic>? mine;
      for (final p in list) {
        if (p['unit_id'] == _unitId) {
          mine = p;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _progress = mine ?? {};
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _markStep(String step) async {
    try {
      final r = await Api.instance.post('/course/progress', {'unitId': _unitId, 'step': step}) as Map;
      if (!mounted) return;
      setState(() => _progress = r.cast<String, dynamic>());
      final certificateId = r['certificateId'] as String?;
      if (certificateId != null) await _offerCertificate(certificateId);
    } on ApiError {
      // Best-effort; the local checklist still reflects what just happened.
    }
  }

  Future<void> _offerCertificate(String certificateId) async {
    Map<String, dynamic>? certificate;
    try {
      final r = await Api.instance.get('/certificates') as Map;
      final list = (r['certificates'] as List).cast<Map<String, dynamic>>();
      for (final c in list) {
        if (c['id'] == certificateId) {
          certificate = c;
          break;
        }
      }
    } on ApiError {
      // Best-effort; the completion itself still shows without a certificate prompt.
    }
    if (certificate == null || !mounted) return;
    final view = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Level complete!'),
        content: const Text("You've earned a certificate for this level."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('View certificate')),
        ],
      ),
    );
    if (view == true) {
      final doc = await buildCertificatePdf(certificate);
      await Printing.layoutPdf(onLayout: (format) => doc.save(), name: '${certificate['piece_name']} certificate.pdf');
    }
  }

  bool get _lessonDone => _progress?['lesson_done'] == true;
  bool get _quizPassed => _progress?['quiz_passed'] == true;
  bool get _puzzlesDone => _progress?['puzzles_done'] == true;
  bool get _botBeaten => _progress?['bot_beaten'] == true;

  Future<void> _openLesson() async {
    try {
      final tutorial = await Api.instance.get('/tutorials/${widget.unit['tutorialId']}') as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutorialScreen(tutorial: tutorial)));
      // Confirm it against the player's own tutorial progress rather than assuming Finish was pressed.
      final progress = (await Api.instance.get('/tutorials/progress') as List).cast<Map<String, dynamic>>();
      final completed = progress.any((p) => p['tutorial_id'] == widget.unit['tutorialId'] && p['completed'] == true);
      if (completed) await _markStep('lesson');
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openQuiz() async {
    final passed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _CourseQuizScreen(unit: widget.unit),
    ));
    if (passed == true) await _markStep('quiz');
  }

  Future<void> _openPuzzles() async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _CoursePracticeScreen(unit: widget.unit),
    ));
    if (done == true) await _markStep('puzzles');
  }

  Future<void> _openBot() async {
    final botMatches = AppConfig.current?.bots.where((b) => b['id'] == widget.unit['botId']) ?? const [];
    final bot = botMatches.isEmpty ? null : botMatches.first;
    if (bot == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hints are off for this game, so the win counts.')),
    );
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BotGameScreen(bot: bot, playWhite: true, assistedMode: false),
    ));
    if (!mounted) return;
    try {
      final me = await Api.instance.get('/me') as Map;
      final beaten = ((me['bots'] as Map?)?['beaten'] as List?)?.cast<String>() ?? const [];
      if (beaten.contains(widget.unit['botId'])) await _markStep('bot');
    } on ApiError {
      // Best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final unit = widget.unit;
    final allDone = _progress != null && _lessonDone && _quizPassed && _puzzlesDone && _botBeaten;
    return Scaffold(
      appBar: AppBar(title: Text('${unit['pieceName']} -- ${unit['title']}')),
      body: _progress == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(HcSpace.s4),
              children: [
                Text(unit['description'] as String? ?? '', style: HcText.body.copyWith(color: hc.ink2)),
                const SizedBox(height: HcSpace.s4),
                if (allDone)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HcSpace.s3),
                    child: Row(children: [
                      Icon(Icons.emoji_events_rounded, color: hc.green),
                      const SizedBox(width: 8),
                      Text('Level complete!', style: HcText.titleMd.copyWith(color: hc.green)),
                    ]),
                  ),
                HcListGroup(children: [
                  HcListRow(
                    leading: _stepIcon(hc, _lessonDone),
                    title: 'Lesson',
                    subtitle: 'Read through the lesson',
                    trailing: Icon(Icons.chevron_right_rounded, color: hc.ink3),
                    onTap: _openLesson,
                  ),
                  HcListRow(
                    leading: _stepIcon(hc, _puzzlesDone),
                    title: 'Practice puzzles',
                    subtitle: '${unit['puzzleCount']} puzzles',
                    trailing: Icon(Icons.chevron_right_rounded, color: hc.ink3),
                    onTap: _openPuzzles,
                  ),
                  HcListRow(
                    leading: _stepIcon(hc, _quizPassed),
                    title: 'Quiz',
                    subtitle: '${(unit['quiz'] as List).length} questions',
                    trailing: Icon(Icons.chevron_right_rounded, color: hc.ink3),
                    onTap: _openQuiz,
                  ),
                  HcListRow(
                    leading: _stepIcon(hc, _botBeaten),
                    title: 'Beat the bot',
                    subtitle: 'Win a game, no hints',
                    trailing: Icon(Icons.chevron_right_rounded, color: hc.ink3),
                    onTap: _openBot,
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _stepIcon(HcPalette hc, bool done) => Container(
        width: HcSize.avatarMd,
        height: HcSize.avatarMd,
        decoration: BoxDecoration(color: done ? hc.greenSoft : hc.surface2, borderRadius: BorderRadius.circular(HcRadius.sm)),
        alignment: Alignment.center,
        child: Icon(done ? Icons.check_rounded : Icons.circle_outlined, color: done ? hc.green : hc.ink3),
      );
}

/// A short multiple-choice quiz for one unit; pops `true` if the player passes (>=80%).
class _CourseQuizScreen extends StatefulWidget {
  const _CourseQuizScreen({required this.unit});
  final Map<String, dynamic> unit;

  @override
  State<_CourseQuizScreen> createState() => _CourseQuizScreenState();
}

class _CourseQuizScreenState extends State<_CourseQuizScreen> {
  late final List<Map<String, dynamic>> _questions = (widget.unit['quiz'] as List).cast<Map<String, dynamic>>();
  int _i = 0;
  int? _picked;
  int _correct = 0;
  bool _done = false;

  Map<String, dynamic> get _q => _questions[_i];

  void _pick(int choice) {
    if (_picked != null) return;
    setState(() {
      _picked = choice;
      if (choice == _q['correct']) _correct++;
    });
  }

  void _next() {
    if (_i >= _questions.length - 1) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _i++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final passed = _correct / _questions.length >= 0.8;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HcSpace.s4),
          child: _done
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$_correct / ${_questions.length} correct', style: HcText.displayMd.copyWith(color: hc.ink)),
                    const SizedBox(height: HcSpace.s3),
                    Text(
                      passed ? 'Passed!' : 'Not quite -- you need 80% to pass.',
                      style: HcText.titleMd.copyWith(color: passed ? hc.green : hc.dangerInk),
                    ),
                    const SizedBox(height: HcSpace.s4),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(passed),
                      style: HcButtons.large(),
                      child: Text(passed ? 'Continue' : 'Close'),
                    ),
                  ]),
                )
              : ListView(children: [
                  Text('${_i + 1} / ${_questions.length}', style: HcText.label.copyWith(color: hc.ink2)),
                  const SizedBox(height: HcSpace.s3),
                  Text(_q['question'] as String, style: HcText.titleMd.copyWith(color: hc.ink)),
                  const SizedBox(height: HcSpace.s3),
                  for (var c = 0; c < (_q['choices'] as List).length; c++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () => _pick(c),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _picked == null
                              ? null
                              : c == _q['correct']
                                  ? hc.greenSoft
                                  : c == _picked
                                      ? hc.dangerSoft
                                      : null,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text((_q['choices'] as List)[c] as String),
                      ),
                    ),
                  if (_picked != null)
                    Padding(
                      padding: const EdgeInsets.only(top: HcSpace.s2),
                      child: FilledButton(onPressed: _next, child: Text(_i >= _questions.length - 1 ? 'Finish' : 'Next')),
                    ),
                ]),
        ),
      ),
    );
  }
}

/// Practices this unit's puzzle batch (GET /puzzles/pack filtered by theme/rating). Pops
/// `true` once every puzzle in the batch has been attempted (solved or failed) -- this is
/// practice, not a pass/fail gate, so an imperfect run still finishes the step.
class _CoursePracticeScreen extends StatefulWidget {
  const _CoursePracticeScreen({required this.unit});
  final Map<String, dynamic> unit;

  @override
  State<_CoursePracticeScreen> createState() => _CoursePracticeScreenState();
}

class _CoursePracticeScreenState extends State<_CoursePracticeScreen> {
  List<Puzzle>? _pack;
  int _i = 0;
  PuzzleSession? _session;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final theme = widget.unit['puzzleTheme'] as String?;
      final r = await Api.instance.get('/puzzles/pack', {
        'count': '${widget.unit['puzzleCount']}',
        'theme': ?theme,
      }) as Map;
      final puzzles = ((r['puzzles'] as List).cast<Map>()).map((p) => Puzzle.fromJson(p.cast<String, dynamic>())).toList();
      if (!mounted) return;
      if (puzzles.isEmpty) {
        setState(() => _error = 'No puzzles available for this level right now.');
        return;
      }
      setState(() {
        _pack = puzzles;
        _session = PuzzleSession(puzzles.first);
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool _onMove(String from, String to, String? promo) {
    final s = _session;
    if (s == null) return false;
    final ok = s.tryMove(from, to, promo);
    if (!ok) return false;
    setState(() {});
    if (s.awaitingReply) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(s.playReply);
        _finishIfDone(s);
      });
    } else {
      _finishIfDone(s);
    }
    return true;
  }

  Future<void> _finishIfDone(PuzzleSession s) async {
    if (s.status == PuzzleStatus.playing || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Api.instance.post('/puzzles/${s.puzzle.id}/attempt', {
        'success': s.status == PuzzleStatus.solved,
        'hintsUsed': s.maxHintLevel,
      });
    } on ApiError {
      // Best-effort; still advances to the next puzzle in the batch.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _next() {
    final pack = _pack!;
    if (_i >= pack.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _i++;
      _session = PuzzleSession(pack[_i]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final pack = _pack;
    final s = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Practice puzzles')),
      body: SafeArea(
        child: pack == null || s == null
            ? Center(
                child: _error != null
                    ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                    : const CircularProgressIndicator(),
              )
            : ListView(
                padding: const EdgeInsets.all(HcSpace.s4),
                children: [
                  Text('Puzzle ${_i + 1} / ${pack.length}', style: HcText.label.copyWith(color: hc.ink2)),
                  const SizedBox(height: HcSpace.s3),
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(HcRadius.board),
                      child: ChessBoardView(
                        key: ValueKey(s.puzzle.id),
                        fen: s.fen,
                        whiteAtBottom: s.whiteToSolve,
                        lastMove: s.lastMove,
                        lastMoveSan: s.lastSan,
                        hintSquare: s.hintFrom,
                        arrow: s.hintTo != null ? (s.hintFrom!, s.hintTo!) : null,
                        onMove: s.status == PuzzleStatus.playing && !s.awaitingReply ? _onMove : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: HcSpace.s3),
                  Text(
                    switch (s.status) {
                      PuzzleStatus.playing => '${s.whiteToSolve ? 'White' : 'Black'} to play.',
                      PuzzleStatus.solved => 'Solved!',
                      PuzzleStatus.failed => 'Not quite -- that happens, keep going.',
                    },
                    style: HcText.titleMd.copyWith(color: hc.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HcSpace.s3),
                  Row(children: [
                    if (s.status == PuzzleStatus.playing)
                      TextButton(onPressed: s.showHint, child: const Text('Hint')),
                    const Spacer(),
                    if (s.status != PuzzleStatus.playing)
                      FilledButton(onPressed: _next, child: Text(_i >= pack.length - 1 ? 'Finish' : 'Next puzzle')),
                  ]),
                ],
              ),
      ),
    );
  }
}
