import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';

const _roundSeconds = 30;

/// Tap the named square before time runs out: 30-second rounds, with a personal best synced
/// server-side (GET/POST /coordinates/best). No boards or pieces -- a plain 8x8 grid is all
/// this drill needs.
class CoordinatesTrainerScreen extends StatefulWidget {
  const CoordinatesTrainerScreen({super.key});

  @override
  State<CoordinatesTrainerScreen> createState() => _CoordinatesTrainerScreenState();
}

class _CoordinatesTrainerScreenState extends State<CoordinatesTrainerScreen> {
  final _random = Random();
  Timer? _timer;
  bool _running = false;
  String? _target;
  int _score = 0;
  int? _lastScore;
  int? _best;
  int _secondsLeft = _roundSeconds;
  String? _wrongFlash;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final r = await Api.instance.get('/coordinates/best') as Map;
      if (mounted) setState(() => _best = (r['best'] as num?)?.toInt());
    } on ApiError {
      // Best-effort; the drill works fine without a known best to beat.
    }
  }

  String _randomSquare() => '${'abcdefgh'[_random.nextInt(8)]}${_random.nextInt(8) + 1}';

  void _start() {
    _timer?.cancel();
    setState(() {
      _running = true;
      _score = 0;
      _secondsLeft = _roundSeconds;
      _target = _randomSquare();
      _wrongFlash = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _finish();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _tap(String square) {
    if (!_running) return;
    if (square == _target) {
      setState(() {
        _score++;
        _target = _randomSquare();
      });
    } else {
      setState(() => _wrongFlash = square);
      Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _wrongFlash = null);
      });
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final score = _score;
    setState(() {
      _running = false;
      _lastScore = score;
      _target = null;
      if (_best == null || score > _best!) _best = score;
    });
    try {
      final r = await Api.instance.post('/coordinates/best', {'score': score}) as Map;
      if (mounted) setState(() => _best = (r['best'] as num?)?.toInt() ?? _best);
    } on ApiError {
      // Best-effort; the local best shown already reflects this round.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Scaffold(
      appBar: AppBar(title: const Text('Coordinates trainer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HcSpace.s4),
          children: [
            if (_running) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Score: $_score', style: HcText.titleMd.copyWith(color: hc.ink)),
                Text('${_secondsLeft}s', style: HcText.clockSm.copyWith(color: hc.ink)),
              ]),
              const SizedBox(height: HcSpace.s3),
              Text('Tap ${_target!.toUpperCase()}', style: HcText.displayLg.copyWith(color: hc.ink), textAlign: TextAlign.center),
              const SizedBox(height: HcSpace.s4),
            ] else ...[
              Text(
                'Tap the named square before time runs out.',
                style: HcText.body.copyWith(color: hc.ink2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HcSpace.s3),
              if (_lastScore != null) Text('Last round: $_lastScore', style: HcText.titleMd.copyWith(color: hc.ink)),
              if (_best != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Best: $_best', style: HcText.bodySm.copyWith(color: hc.ink2)),
                ),
              const SizedBox(height: HcSpace.s3),
              FilledButton(
                onPressed: _start,
                style: HcButtons.large(),
                child: Text(_lastScore == null ? 'Start' : 'Play again'),
              ),
              const SizedBox(height: HcSpace.s4),
            ],
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (context, i) {
                  final file = 'abcdefgh'[i % 8];
                  final rank = 8 - i ~/ 8;
                  final square = '$file$rank';
                  final light = (i % 8 + i ~/ 8) % 2 == 0;
                  final wrong = _wrongFlash == square;
                  return GestureDetector(
                    key: Key('square_$square'),
                    onTap: _running ? () => _tap(square) : null,
                    child: Container(color: wrong ? hc.dangerSoft : (light ? hc.surface2 : hc.surface3)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
