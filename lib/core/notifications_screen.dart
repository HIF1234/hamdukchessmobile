import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../games/game_screen.dart';
import 'api.dart';
import 'hc_widgets.dart';
import 'links.dart';
import 'theme.dart';

class _Notice {
  const _Notice({required this.id, required this.title, this.body, this.link, required this.read, required this.at});
  final String id;
  final String title;
  final String? body;
  final String? link;
  final bool read;
  final DateTime at;

  factory _Notice.fromApi(Map<String, dynamic> j) => _Notice(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        link: j['link'] as String?,
        read: j['read'] as bool? ?? false,
        at: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_Notice>? _notices;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/notifications') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _notices = (r['notifications'] as List).cast<Map<String, dynamic>>().map(_Notice.fromApi).toList();
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(_Notice n) async {
    if (!n.read) {
      unawaited(Api.instance.post('/notifications/read', {'ids': [n.id]}));
      setState(() {
        _notices = [
          for (final x in _notices!)
            if (x.id == n.id)
              _Notice(id: x.id, title: x.title, body: x.body, link: x.link, read: true, at: x.at)
            else
              x,
        ];
      });
    }
    final link = n.link;
    if (link == null || !mounted) return;
    final gameId = gameIdFrom(Uri.parse('https://play.chess.hamduk.com.ng$link'));
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (gameId != null && me != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(gameId: gameId, myId: me)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notices = _notices;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notices != null && notices.any((n) => !n.read))
            TextButton(
              onPressed: () async {
                await Api.instance.post('/notifications/read', {});
                await _load();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: notices == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : notices != null && notices.isEmpty
                ? EmptyState(icon: Icons.notifications_none_rounded, title: 'No notifications yet', body: "You'll see game and social updates here.")
                : ListView(
                    padding: const EdgeInsets.all(HcSpace.s4),
                    children: [
                      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: HcSpace.s3), child: Text(_error!)),
                      HcListGroup(children: [
                        for (final n in notices ?? const <_Notice>[])
                          HcListRow(
                            onTap: () => _open(n),
                            leading: Container(
                              width: HcSize.avatarMd,
                              height: HcSize.avatarMd,
                              decoration: BoxDecoration(
                                color: n.read ? context.hc.surface2 : context.hc.green,
                                borderRadius: BorderRadius.circular(HcRadius.sm),
                              ),
                              child: Icon(Icons.notifications_rounded, color: n.read ? context.hc.ink2 : context.hc.onGreen, size: 18),
                            ),
                            title: n.title,
                            subtitle: n.body,
                            trailing: Text(_relative(n.at), style: HcText.bodySm.copyWith(color: context.hc.ink3)),
                          ),
                      ]),
                    ],
                  ),
      ),
    );
  }
}

String _relative(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}
