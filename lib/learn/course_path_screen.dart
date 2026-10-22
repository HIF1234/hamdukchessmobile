import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'certificates_screen.dart';
import 'course_unit_screen.dart';

/// "A full course from first move to club player": six levels named after the pieces, Pawn
/// to King. Each level unlocks the next once its unit (lesson + quiz + puzzles + bot) is
/// fully done, via GET /course (static curriculum) and GET /course/progress.
class CoursePathScreen extends StatefulWidget {
  const CoursePathScreen({super.key});

  @override
  State<CoursePathScreen> createState() => _CoursePathScreenState();
}

class _CoursePathScreenState extends State<CoursePathScreen> {
  List<Map<String, dynamic>>? _units;
  Map<String, Map<String, dynamic>> _progress = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/course') as Map;
      final units = (r['units'] as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> progress = const [];
      try {
        final p = await Api.instance.get('/course/progress') as Map;
        progress = (p['progress'] as List).cast<Map<String, dynamic>>();
      } on ApiError {
        // Best-effort; the course still shows, just without known progress.
      }
      if (!mounted) return;
      setState(() {
        _units = units..sort((a, b) => (a['level'] as num).compareTo(b['level'] as num));
        _progress = {for (final p in progress) p['unit_id'] as String: p};
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool _isComplete(Map<String, dynamic> unit) => _progress[unit['id']]?['completed_at'] != null;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final units = _units;
    return Scaffold(
      appBar: AppBar(title: const Text('Course path'), actions: [
        IconButton(
          icon: const Icon(Icons.workspace_premium_outlined),
          tooltip: 'My certificates',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CertificatesScreen())),
        ),
      ]),
      body: units == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(HcSpace.s4),
                children: [
                  Text(
                    'Six levels, Pawn to King. Finish a level -- lesson, practice puzzles, a quiz and a bot to beat -- to unlock the next.',
                    style: HcText.body.copyWith(color: hc.ink2),
                  ),
                  const SizedBox(height: HcSpace.s4),
                  HcListGroup(children: [
                    for (var i = 0; i < units.length; i++) ...[_unitRow(hc, units, i)],
                  ]),
                ],
              ),
            ),
    );
  }

  Widget _unitRow(HcPalette hc, List<Map<String, dynamic>> units, int i) {
    final unit = units[i];
    final complete = _isComplete(unit);
    final locked = i > 0 && !_isComplete(units[i - 1]);
    final progress = _progress[unit['id']];
    final doneCount = progress == null
        ? 0
        : [progress['lesson_done'], progress['quiz_passed'], progress['puzzles_done'], progress['bot_beaten']].where((v) => v == true).length;
    return HcListRow(
      leading: Container(
        width: HcSize.avatarMd,
        height: HcSize.avatarMd,
        decoration: BoxDecoration(
          color: complete ? hc.greenSoft : (locked ? hc.surface2 : hc.surface3),
          borderRadius: BorderRadius.circular(HcRadius.sm),
        ),
        alignment: Alignment.center,
        child: Text('${unit['level']}', style: HcText.titleSm.copyWith(color: complete ? hc.green : hc.ink2)),
      ),
      title: '${unit['pieceName']} -- ${unit['title']}',
      subtitle: locked ? 'Finish the level before this one to unlock' : (complete ? 'Completed' : '$doneCount of 4 parts done'),
      trailing: complete
          ? Icon(Icons.check_circle_rounded, color: hc.green)
          : locked
              ? Icon(Icons.lock_outline_rounded, color: hc.ink3)
              : Icon(Icons.chevron_right_rounded, color: hc.ink3),
      onTap: locked
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseUnitScreen(unit: unit))).then((_) => _load()),
    );
  }
}
