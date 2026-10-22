import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api.dart';
import '../core/settings.dart';
import '../profile/subscription_sheet.dart';

/// "245 MB" / "1.2 GB" -- for the size shown before playing a cloud-hosted lesson.
String formatFileSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Plays one video lesson. YouTube/Vimeo embed directly by external_id; cloud-hosted lessons
/// mint a signed URL first (POST /videos/{id}/url), which also enforces Gold-tier gating
/// server-side. YouTube/Vimeo premium lessons aren't gated server-side, so [canWatch] (computed
/// by the caller from /me's billing tier) gates them client-side, same as the website.
/// Progress is reported periodically via POST /videos/progress.
///
/// Low-data mode: rather than auto-streaming, shows a gate with the size (when known) and a
/// "Stream now" button -- except once a cloud lesson has been downloaded, which plays from disk
/// and uses no data at all. Only cloud-hosted lessons can be downloaded ("Download on WiFi");
/// YouTube/Vimeo content isn't ours to save for offline use.
class VideoLessonScreen extends StatefulWidget {
  const VideoLessonScreen({super.key, required this.lesson, required this.canWatch, this.debugDocumentsDir});
  final Map<String, dynamic> lesson;
  final bool canWatch;

  /// Overrides where a downloaded lesson is looked for/saved -- for tests only, same idea as
  /// `JsonStore.at(dir)`. Production code leaves this null and uses the real documents directory.
  final Directory? debugDocumentsDir;

  @override
  State<VideoLessonScreen> createState() => _VideoLessonScreenState();
}

class _VideoLessonScreenState extends State<VideoLessonScreen> {
  WebViewController? _controller;
  String? _error;
  Timer? _progressTimer;
  int _watchedSec = 0;

  bool get _isCloud => widget.lesson['source'] == 'cloud';
  int? get _sizeBytes => (widget.lesson['file_size_bytes'] as num?)?.toInt();

  bool _lowDataGate = false;
  File? _downloadedFile;
  bool _downloading = false;
  double? _downloadProgress;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<File> _localFile() async {
    final dir = widget.debugDocumentsDir ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/video_lessons/${widget.lesson['id']}.mp4');
  }

  Future<void> _start() async {
    if (_isCloud) {
      final f = await _localFile();
      if (await f.exists()) {
        if (!mounted) return;
        setState(() => _downloadedFile = f);
        _playFromLocal(f);
        return;
      }
    }
    if (AppSettings.instance.lowData) {
      if (mounted) setState(() => _lowDataGate = true);
      return;
    }
    _stream();
  }

  void _playFromLocal(File f) {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.file(f.path));
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = 'Video playback isn\'t available on this device.');
    }
  }

  Future<void> _stream() async {
    if (!widget.canWatch) return;
    setState(() => _lowDataGate = false);
    final lesson = widget.lesson;
    String? url;
    switch (lesson['source']) {
      case 'youtube':
        url = 'https://www.youtube.com/embed/${lesson['external_id']}?playsinline=1';
      case 'vimeo':
        url = 'https://player.vimeo.com/video/${lesson['external_id']}';
      case 'cloud':
        try {
          final r = await Api.instance.post('/videos/${lesson['id']}/url') as Map;
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

  Future<void> _download() async {
    if (!_isCloud || _downloading) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.wifi)) {
      if (mounted) setState(() => _downloadError = 'Connect to WiFi to download this lesson.');
      return;
    }
    setState(() {
      _downloading = true;
      _downloadError = null;
      _downloadProgress = 0;
    });
    try {
      final r = await Api.instance.post('/videos/${widget.lesson['id']}/url') as Map;
      final url = r['url'] as String?;
      if (url == null) throw ApiError('error', 'No download URL returned.');
      final response = await Api.client.send(http.Request('GET', Uri.parse(url)));
      final total = response.contentLength;
      final file = await _localFile();
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.part');
      final sink = tmp.openWrite();
      var received = 0;
      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0 && mounted) setState(() => _downloadProgress = received / total);
      }).asFuture<void>();
      await sink.close();
      await tmp.rename(file.path);
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloadProgress = null;
        _downloadedFile = file;
      });
      if (_controller == null) _playFromLocal(file);
    } on ApiError catch (e) {
      if (mounted) setState(() => _downloadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _downloadError = 'Download failed.');
    } finally {
      if (mounted && _downloading) setState(() => _downloading = false);
    }
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
                ? _goldGate(t)
                : _lowDataGate
                    ? _lowDataGateView(t)
                    : _error != null
                        ? _errorView(t)
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
                '${widget.lesson['instructor'] ?? ''} · ${widget.lesson['difficulty'] ?? ''}'
                '${_sizeBytes != null ? ' · ${formatFileSize(_sizeBytes!)}' : ''}',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              if ((widget.lesson['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(widget.lesson['description'] as String, style: t.textTheme.bodyMedium),
              ],
              if (_isCloud && _downloadedFile == null) ...[
                const SizedBox(height: 16),
                if (_downloading)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(value: _downloadProgress),
                    const SizedBox(height: 6),
                    Text(
                      _downloadProgress != null ? 'Downloading… ${(_downloadProgress! * 100).round()}%' : 'Downloading…',
                      style: t.textTheme.bodySmall,
                    ),
                  ])
                else
                  OutlinedButton.icon(
                    onPressed: _download,
                    icon: const Icon(Icons.wifi_rounded),
                    label: const Text('Download on WiFi'),
                  ),
                if (_downloadError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_downloadError!, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.error)),
                  ),
              ],
              if (_downloadedFile != null) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Icon(Icons.offline_pin_rounded, color: t.colorScheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Downloaded -- plays without using data', style: t.textTheme.bodySmall),
                ]),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _goldGate(ThemeData t) => Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium, color: t.colorScheme.secondary, size: 32),
            const SizedBox(height: 10),
            const Text('This lesson is on the Gold plan.', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => showSubscriptionSheet(context, 'free'), child: const Text('Upgrade')),
          ]),
        ),
      );

  Widget _errorView(ThemeData t) => Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
        ),
      );

  Widget _lowDataGateView(ThemeData t) => Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.data_saver_off_rounded, color: Colors.white70, size: 32),
            const SizedBox(height: 10),
            Text(
              "You're in low-data mode."
              '${_sizeBytes != null ? ' This lesson is ${formatFileSize(_sizeBytes!)}.' : ''}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _stream, child: const Text('Stream now')),
          ]),
        ),
      );
}
