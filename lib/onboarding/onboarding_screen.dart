import 'package:flutter/material.dart';

import '../core/hc_widgets.dart';
import '../core/settings.dart';
import '../core/storage.dart';
import '../core/theme.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.public,
    'Chess, built for Africa',
    'Fast, low-data play that works on any phone and any connection — a home-grown rival to the big sites, at a price that makes sense here.',
  ),
  _Slide(
    Icons.sports_esports,
    'Play online or offline',
    'Match with real opponents worldwide, challenge a friend on WhatsApp, or play Naija bots with zero data used.',
  ),
];

/// "How well do you play?" sets the starting rating (and whether the first game is a bot
/// match or the "how pieces move" tutorial first) -- see PendingFirstMove.
const _levels = [
  ('New to chess', 400, true),
  ('I know the moves', 800, false),
  ('Club player', 1200, false),
  ('Tournament player', 1600, false),
];

const _onboardingSeenKey = 'onboarding_seen';

Future<bool> hasSeenOnboarding() async {
  final store = await JsonStore.open();
  return (await store.read(_onboardingSeenKey)) == true;
}

/// What onboarding collected, for the caller to act on (seed a guest sign-in, route the
/// first move) once the flow finishes.
class OnboardingResult {
  const OnboardingResult({required this.startingRating, required this.beginner});
  final int startingRating;
  final bool beginner;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final void Function(OnboardingResult result) onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { language, slides, level }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  _Step _step = _Step.language;
  int _slide = 0;

  Future<void> _finish(int startingRating, bool beginner) async {
    final store = await JsonStore.open();
    await store.write(_onboardingSeenKey, true);
    widget.onDone(OnboardingResult(startingRating: startingRating, beginner: beginner));
  }

  void _afterLanguage() => setState(() => _step = _Step.slides);

  void _nextSlide() {
    if (_slide == _slides.length - 1) {
      setState(() => _step = _Step.level);
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _skipSlides() => setState(() => _step = _Step.level);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HcColors.forest,
      body: SafeArea(
        child: Column(
          children: [
            const AsoOkeStrip(),
            const SizedBox(height: HcSpace.s4),
            Text('Hamduk Chess', style: HcText.displayMd.copyWith(color: HcColors.onForest)),
            const SizedBox(height: HcSpace.s5),
            Expanded(
              child: switch (_step) {
                _Step.language => _LanguageStep(onNext: _afterLanguage),
                _Step.slides => _SlidesStep(controller: _controller, slide: _slide, onChanged: (i) => setState(() => _slide = i)),
                _Step.level => _LevelStep(onPicked: _finish),
              },
            ),
            if (_step == _Step.slides) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: HcSpace.s4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _slide ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _slide ? HcColors.brandGold : HcColors.onForest2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(HcSpace.s6, 0, HcSpace.s6, HcSpace.s6),
                child: Row(children: [
                  TextButton(onPressed: _skipSlides, child: const Text('Skip', style: TextStyle(color: HcColors.onForest2))),
                  const Spacer(),
                  FilledButton(style: HcButtons.large(), onPressed: _nextSlide, child: const Text('Next')),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageStep extends StatefulWidget {
  const _LanguageStep({required this.onNext});
  final VoidCallback onNext;

  @override
  State<_LanguageStep> createState() => _LanguageStepState();
}

class _LanguageStepState extends State<_LanguageStep> {
  String _chosen = 'en';

  Future<void> _pick(String code) async {
    setState(() => _chosen = code);
    await AppSettings.instance.setLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Choose your language', style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s2),
        Text('Changeable any time in Settings.', style: HcText.body.copyWith(color: HcColors.onForest2), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(HcSpace.s3),
          decoration: BoxDecoration(color: hc.surface, borderRadius: BorderRadius.circular(HcRadius.xl)),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final entry in appLanguages.entries)
                  ListTile(
                    title: Text(entry.value, style: HcText.titleMd.copyWith(color: hc.ink)),
                    trailing: entry.key == _chosen ? Icon(Icons.check_rounded, color: hc.green) : null,
                    onTap: () => _pick(entry.key),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: HcSpace.s5),
        SizedBox(
          width: double.infinity,
          child: FilledButton(style: HcButtons.large(), onPressed: widget.onNext, child: const Text('Continue')),
        ),
      ]),
    );
  }
}

class _SlidesStep extends StatelessWidget {
  const _SlidesStep({required this.controller, required this.slide, required this.onChanged});
  final PageController controller;
  final int slide;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      onPageChanged: onChanged,
      children: [for (final s in _slides) _SlideView(slide: s)],
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(color: HcColors.brandGold, shape: BoxShape.circle),
            child: Icon(slide.icon, size: 56, color: HcColors.forest),
          ),
          const SizedBox(height: HcSpace.s7),
          Text(slide.title, style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
          const SizedBox(height: HcSpace.s3),
          Text(slide.body, style: HcText.body.copyWith(color: HcColors.onForest2), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LevelStep extends StatelessWidget {
  const _LevelStep({required this.onPicked});
  final void Function(int startingRating, bool beginner) onPicked;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('How well do you play?', style: HcText.displayMd.copyWith(color: HcColors.onForest), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s2),
        Text('This sets where you start -- you can always prove it wrong.', style: HcText.body.copyWith(color: HcColors.onForest2), textAlign: TextAlign.center),
        const SizedBox(height: HcSpace.s6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(HcSpace.s3),
          decoration: BoxDecoration(color: hc.surface, borderRadius: BorderRadius.circular(HcRadius.xl)),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: [
              for (final (label, rating, beginner) in _levels)
                ListTile(
                  title: Text(label, style: HcText.titleMd.copyWith(color: hc.ink)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onPicked(rating, beginner),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
