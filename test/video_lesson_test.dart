import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/core/settings.dart';
import 'package:hamduk_chess/learn/video_lesson_screen.dart';

void main() {
  tearDown(() => AppSettings.instance.lowData = false);

  Map<String, dynamic> cloudLesson({int? sizeBytes}) => {
        'id': 'lesson-1',
        'title': 'Rook endgames',
        'source': 'cloud',
        'duration_sec': 600,
        'file_size_bytes': sizeBytes,
        'instructor': 'Coach',
        'difficulty': 'intermediate',
        'description': '',
      };

  Map<String, dynamic> youtubeLesson() => {
        'id': 'lesson-2',
        'title': 'Opening principles',
        'source': 'youtube',
        'external_id': 'abc123',
        'duration_sec': 600,
        'file_size_bytes': null,
        'instructor': 'Coach',
        'difficulty': 'beginner',
        'description': '',
      };

  group('formatFileSize', () {
    test('kilobytes', () => expect(formatFileSize(500 * 1024), '500 KB'));
    test('megabytes', () => expect(formatFileSize(245 * 1024 * 1024), '245 MB'));
    test('gigabytes', () => expect(formatFileSize((1.2 * 1024 * 1024 * 1024).round()), '1.2 GB'));
  });

  // Cloud lessons check the local filesystem for a downloaded copy before showing anything;
  // that's real dart:io async, not a Timer, so it needs runAsync to actually complete under
  // flutter_test's fake-async zone -- a plain pump()/pumpAndSettle() never resolves it.
  Future<void> settleRealIo(WidgetTester t) async {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await t.pump();
  }

  testWidgets('low-data mode gates a cloud lesson and shows its size instead of streaming', (t) async {
    AppSettings.instance.lowData = true;
    final dir = Directory.systemTemp.createTempSync('video_lesson_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    await t.pumpWidget(MaterialApp(
      home: VideoLessonScreen(lesson: cloudLesson(sizeBytes: 245 * 1024 * 1024), canWatch: true, debugDocumentsDir: dir),
    ));
    await settleRealIo(t);
    expect(find.textContaining("You're in low-data mode"), findsOneWidget);
    expect(find.textContaining('245 MB'), findsWidgets);
    expect(find.text('Stream now'), findsOneWidget);
  });

  testWidgets('low-data mode gates a YouTube lesson without a size (not known)', (t) async {
    AppSettings.instance.lowData = true;
    await t.pumpWidget(MaterialApp(home: VideoLessonScreen(lesson: youtubeLesson(), canWatch: true)));
    await t.pumpAndSettle();
    expect(find.textContaining("You're in low-data mode"), findsOneWidget);
    expect(find.text('Stream now'), findsOneWidget);
    expect(find.text('Download on WiFi'), findsNothing);
  });

  testWidgets('tapping Stream now dismisses the low-data gate', (t) async {
    AppSettings.instance.lowData = true;
    await t.pumpWidget(MaterialApp(home: VideoLessonScreen(lesson: youtubeLesson(), canWatch: true)));
    await t.pumpAndSettle();
    await t.tap(find.text('Stream now'));
    await t.pumpAndSettle();
    expect(find.text("You're in low-data mode"), findsNothing);
  });

  testWidgets('a downloaded cloud lesson plays from disk and hides the download button', (t) async {
    final dir = Directory.systemTemp.createTempSync('video_lesson_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/video_lessons/lesson-1.mp4');
    file.createSync(recursive: true);
    file.writeAsBytesSync([1, 2, 3]);
    await t.pumpWidget(MaterialApp(
      home: VideoLessonScreen(lesson: cloudLesson(sizeBytes: 100), canWatch: true, debugDocumentsDir: dir),
    ));
    await settleRealIo(t);
    expect(find.text('Download on WiFi'), findsNothing);
    expect(find.textContaining('Downloaded'), findsOneWidget);
  });

  testWidgets('a cloud lesson not yet downloaded offers Download on WiFi', (t) async {
    AppSettings.instance.lowData = true; // avoid firing a real stream request in this test
    final dir = Directory.systemTemp.createTempSync('video_lesson_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    await t.pumpWidget(MaterialApp(
      home: VideoLessonScreen(lesson: cloudLesson(sizeBytes: 100), canWatch: true, debugDocumentsDir: dir),
    ));
    await settleRealIo(t);
    expect(find.text('Download on WiFi'), findsOneWidget);
  });

  testWidgets('Gold-gated lesson shows the upgrade prompt instead of the low-data gate', (t) async {
    AppSettings.instance.lowData = true;
    await t.pumpWidget(MaterialApp(home: VideoLessonScreen(lesson: youtubeLesson(), canWatch: false)));
    await t.pumpAndSettle();
    expect(find.text('This lesson is on the Gold plan.'), findsOneWidget);
    expect(find.text("You're in low-data mode"), findsNothing);
  });
}
