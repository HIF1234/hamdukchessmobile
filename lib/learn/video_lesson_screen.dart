import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api.dart';
import '../profile/subscription_sheet.dart';

/// Plays one video lesson. YouTube/Vimeo embed directly by external_id; cloud-hosted lessons
/// mint a signed URL first (POST /videos/{id}/url), which also enforces Gold-tier gating
/// server-side. YouTube/Vimeo premium lessons aren't gated server-side, so [canWatch] (computed
/// by the caller from /me's billing tier) gates them client-side, same as the website.
/// Progress is reported periodically via POST /videos/progress.
class VideoLessonScreen extends StatefulWidget {
  const VideoLessonScreen({super.key, required this.lesson, required this.canWatch});
  final Map<String, dynamic> lesson;
  final bool canWatch;

  @override
  State<VideoLessonScreen> createState() => _VideoLessonScreenState();
}

class _VideoLessonScreenState extends State<VideoLessonScreen> {
  WebViewController? _controller;
  String? _error;
  Timer? _progressTimer;
  int _watchedSec = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!widget.canWatch) return;
    final lesson = widget.lesson;
    String? url;
    switch (lesson['source']) {
      case 'youtube':
        url = 'https://www.youtube.com/embed/${lesson['external_id']}?playsinline=1';
      case 'vimeo':
        url = 'https://player.vimeo.com/video/${lesson['external_id']}';
      case 'cloud':
        try {
          final r = await Api.instance.post('/videos/${lesson['id']}/url') as Map<String, dynamic>;
          url = r['url'] as String?;
        } on ApiError catch (e) {
          if (mounted) setState(() => _error = e.code == 'upgrade_required' ? 'This lesson is on the Gold plan.' : e.message);
          return;
        }
    }
    if (url == null || !mounted) return;
    final WebViewController controller;
    try {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(url));
    } catch (e) {
      // No platform WebView implementation registered (e.g. a plain widget test, or a device
      // without WebView support) -- fail into the error state rather than crash the screen.
      if (mounted) setState(() => _error = 'Video playback isn\'t available on this device.');
      return;
    }
    setState(() => _controller = controller);
    // Rough watch-time tracking: a lesson counts as "started" once opened, "completed" after a
    // plausible watch duration. There's no cross-player API to read exact position from an
    // embedded YouTube/Vimeo iframe without their JS SDKs, so this stays approximate.
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) => _reportProgress());
  }

  Future<void> _reportProgress({bool completed = false}) async {
    _watchedSec += 15;
    final duration = (widget.lesson['duration_sec'] as num?)?.toInt() ?? 0;
    try {
      await Api.instance.post('/videos/progress', {
        'videoId': widget.lesson['id'],
        'positionSec': _watchedSec,
        'completed': completed || (duration > 0 && _watchedSec >= duration),
      });
    } on ApiError {
      // Best-effort; don't interrupt playback over a progress-sync failure.
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    if (_controller != null) _reportProgress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson['title'] as String)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: !widget.canWatch
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.workspace_premium, color: t.colorScheme.secondary, size: 32),
                        const SizedBox(height: 10),
                        const Text('This lesson is on the Gold plan.', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => showSubscriptionSheet(context, 'free'),
                          child: const Text('Upgrade'),
                        ),
                      ]),
                    ),
                  )
                : _error != null
                    ? Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                        ),
                      )
                    : _controller == null
                        ? const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()))
                        : WebViewWidget(controller: _controller!),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.lesson['title'] as String, style: t.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '${widget.lesson['instructor'] ?? ''} · ${widget.lesson['difficulty'] ?? ''}',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              if ((widget.lesson['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(widget.lesson['description'] as String, style: t.textTheme.bodyMedium),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
