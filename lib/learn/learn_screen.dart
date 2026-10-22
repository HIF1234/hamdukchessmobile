import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'board_vision_screen.dart';
import 'coordinates_trainer_screen.dart';
import 'openings_list_screen.dart';
import 'tutorial_screen.dart';
import 'video_lesson_screen.dart';

/// Learn hub: interactive tutorials (board positions, no video) and video lessons
/// (GET /tutorials, GET /videos). Entered from the Profile tab, same pattern as Coaching.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<Map<String, dynamic>>? _tutorials;
  List<Map<String, dynamic>>? _videos;
  String _tier = 'free';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.instance.get('/tutorials'),
        Api.instance.get('/videos'),
        Api.instance.get('/me'),
      ]);
      if (!mounted) return;
      setState(() {
        _tutorials = (results[0] as List).cast<Map<String, dynamic>>();
        _videos = (results[1] as List).cast<Map<String, dynamic>>();
        _tier = (results[2] as Map)['account']?['tier'] as String? ?? 'free';
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tutorials = _tutorials;
    final videos = _videos;
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!)),
            const SectionLabel('Drills', icon: Icons.bolt_outlined),
            const SizedBox(height: 10),
            HcListGroup(children: [
              HcListRow(
                leading: Container(
                  width: HcSize.avatarMd,
                  height: HcSize.avatarMd,
                  decoration: BoxDecoration(color: context.hc.greenSoft, borderRadius: BorderRadius.circular(HcRadius.sm)),
                  alignment: Alignment.center,
                  child: Icon(Icons.grid_on_rounded, color: context.hc.green),
                ),
                title: 'Coordinates trainer',
                subtitle: 'Tap the named square, 30-second rounds',
                trailing: Icon(Icons.chevron_right_rounded, color: context.hc.ink3),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoordinatesTrainerScreen())),
              ),
              HcListRow(
                leading: Container(
                  width: HcSize.avatarMd,
                  height: HcSize.avatarMd,
                  decoration: BoxDecoration(color: context.hc.greenSoft, borderRadius: BorderRadius.circular(HcRadius.sm)),
                  alignment: Alignment.center,
                  child: Icon(Icons.visibility_outlined, color: context.hc.green),
                ),
                title: 'Board vision',
                subtitle: 'Spot the hanging piece or the check, 10 seconds each',
                trailing: Icon(Icons.chevron_right_rounded, color: context.hc.ink3),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoardVisionScreen())),
              ),
              HcListRow(
                leading: Container(
                  width: HcSize.avatarMd,
                  height: HcSize.avatarMd,
                  decoration: BoxDecoration(color: context.hc.greenSoft, borderRadius: BorderRadius.circular(HcRadius.sm)),
                  alignment: Alignment.center,
                  child: Icon(Icons.auto_stories_outlined, color: context.hc.green),
                ),
                title: 'Opening trainer',
                subtitle: '15 repertoire lines, move-by-move quizzes',
                trailing: Icon(Icons.chevron_right_rounded, color: context.hc.ink3),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpeningsListScreen())),
              ),
            ]),
            const SizedBox(height: HcSpace.s4),
            if (tutorials == null && videos == null && _error == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator())),
            if (tutorials != null) ...[
              const SectionLabel('Tutorials', icon: Icons.menu_book_outlined),
              Text(
                'Play through real positions -- no video, works offline once loaded.',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              for (final topic in _groupBy(tutorials, (m) => m['topic'] as String? ?? 'basics').entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Text(
                    topic.key == 'middlegame' ? 'Middlegame' : 'Basics',
                    style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                HcListGroup(children: [
                  for (final tut in topic.value)
                    HcListRow(
                      leading: Container(
                        width: HcSize.avatarMd,
                        height: HcSize.avatarMd,
                        decoration: BoxDecoration(color: context.hc.greenSoft, borderRadius: BorderRadius.circular(HcRadius.sm)),
                        alignment: Alignment.center,
                        child: Text('${(tut['steps'] as List).length}', style: HcText.titleSm.copyWith(color: context.hc.green)),
                      ),
                      title: tut['title'] as String,
                      subtitle: '${tut['level']} · ${tut['estimatedMinutes']} min',
                      trailing: Icon(Icons.chevron_right_rounded, color: context.hc.ink3),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutorialScreen(tutorial: tut))),
                    ),
                ]),
              ],
              const SizedBox(height: HcSpace.s4),
            ],
            if (videos != null) ...[
              const SectionLabel('Video lessons', icon: Icons.play_circle_outline),
              const SizedBox(height: 4),
              for (final cat in _groupBy(videos, (m) => m['category'] as String? ?? 'General').entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Text(
                    cat.key,
                    style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                HcListGroup(children: [
                  for (final v in cat.value)
                    HcListRow(
                      leading: Container(
                        width: HcSize.avatarMd,
                        height: HcSize.avatarMd,
                        decoration: BoxDecoration(color: context.hc.surface2, borderRadius: BorderRadius.circular(HcRadius.sm)),
                        alignment: Alignment.center,
                        child: Icon(Icons.play_arrow_rounded, color: context.hc.green),
                      ),
                      title: v['title'] as String,
                      subtitle: '${v['instructor'] ?? v['difficulty']} · ${_duration(v['duration_sec'] as num?)}',
                      trailing: v['is_premium'] == true
                          ? Icon(Icons.workspace_premium_rounded, color: context.hc.gold, size: 20)
                          : Icon(Icons.chevron_right_rounded, color: context.hc.ink3),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => VideoLessonScreen(lesson: v, canWatch: v['is_premium'] != true || _tier == 'gold'))),
                    ),
                ]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _duration(num? sec) {
    if (sec == null) return '';
    final s = sec.toInt();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Map<String, List<Map<String, dynamic>>> _groupBy(List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) key) {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final i in items) {
      out.putIfAbsent(key(i), () => []).add(i);
    }
    return out;
  }
}
