import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'puzzles_screen.dart' show puzzleThemes;

/// How this player is doing on each tactical theme they've tried, weakest first -- the
/// server already sorts it that way. Mirrors the web's getMyThemeProgress (attempted,
/// solved, due-for-review via spaced repetition). No design spec exists for this screen
/// yet; built with the app's own tokens (HcListRow, HeroCard) rather than inventing new chrome.
class ThemeStatsScreen extends StatefulWidget {
  const ThemeStatsScreen({super.key});

  @override
  State<ThemeStatsScreen> createState() => _ThemeStatsScreenState();
}

class _ThemeStatsScreenState extends State<ThemeStatsScreen> {
  List<Map<String, dynamic>>? _themes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Api.instance.get('/puzzles/theme-stats') as Map;
      if (mounted) setState(() => _themes = (r['themes'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// "fork" -> "Forks"; falls back to the raw key for a theme not in the picker's list.
  String _label(String key) => puzzleThemes.firstWhere((t) => t.$1 == key, orElse: () => (key, key)).$2;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final themes = _themes;
    return Scaffold(
      appBar: AppBar(title: const Text('Stats by theme')),
      body: themes == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : themes.isEmpty
              ? const EmptyState(
                  icon: Icons.insights_rounded,
                  title: 'No puzzles solved yet',
                  body: 'Solve a few puzzles in each theme and your accuracy will show up here.',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: HcSpace.s4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s4, HcSpace.s4, HcSpace.s2),
                      child: HeroCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HeroCard.overline('Weakest theme'),
                            const SizedBox(height: HcSpace.s1),
                            Text(
                              _label(themes.first['theme'] as String),
                              style: HcText.ratingXl.copyWith(color: hc.gold),
                            ),
                            const SizedBox(height: HcSpace.s1),
                            HeroCard.sub('${themes.first['accuracy']}% accuracy over ${themes.first['attempted']} puzzles'),
                          ],
                        ),
                      ),
                    ),
                    for (final t in themes)
                      HcListRow(
                        title: _label(t['theme'] as String),
                        subtitle: (t['due'] as int) > 0
                            ? '${t['solved']} of ${t['attempted']} solved · ${t['due']} due for review'
                            : '${t['solved']} of ${t['attempted']} solved',
                        trailing: Text(
                          '${t['accuracy']}%',
                          style: HcText.titleSm.copyWith(
                            color: (t['accuracy'] as int) >= 70 ? hc.green : ((t['accuracy'] as int) >= 40 ? hc.ink : hc.dangerInk),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
