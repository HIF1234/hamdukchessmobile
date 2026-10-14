import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../profile/public_profile_screen.dart';
import 'conversation_screen.dart';

/// Friends, activity feed and direct messages -- the social layer every serious chess
/// platform leans on for retention, built on the website's existing follows/friends/
/// messages tables via /api/app/v1/social/*.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(children: [
      ScreenHeader(
        title: 'Social',
        subtitle: 'Friends, activity and messages',
        actions: [
          IconButton(onPressed: () => _tabs.animateTo(0), icon: const Icon(Icons.person_add_alt_1_rounded)),
        ],
      ),
      Container(
        color: t.colorScheme.surface,
        child: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Friends'), Tab(text: 'Feed'), Tab(text: 'Messages')],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: const [_FriendsTab(), _FeedTab(), _MessagesTab()]),
      ),
    ]);
  }
}

class _FriendsTab extends StatefulWidget {
  const _FriendsTab();

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  Map<String, dynamic>? _data;
  String? _error;
  final _search = TextEditingController();
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/social/friends') as Map<String, dynamic>;
      if (mounted) setState(() => _data = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _addByUsername() async {
    final username = _search.text.trim();
    if (username.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final profile = await Api.instance.get('/profile/$username') as Map<String, dynamic>;
      final id = (profile['profile'] as Map?)?['id'] as String?;
      if (id == null) {
        setState(() => _searchError = 'No player with that username.');
        return;
      }
      await Api.instance.post('/social/friends/request', {'userId': id});
      _search.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent.')));
    } on ApiError catch (e) {
      setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _respond(String requestId, bool accept) async {
    try {
      await Api.instance.post('/social/friends/respond', {'requestId': requestId, 'accept': accept});
      await _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final data = _data;
    if (_error != null) return Center(child: Text(_error!));
    if (data == null) return const Center(child: CircularProgressIndicator());
    final accepted = (data['accepted'] as List).cast<Map<String, dynamic>>();
    final incoming = (data['incoming'] as List).cast<Map<String, dynamic>>();
    final outgoing = (data['outgoing'] as List).cast<Map<String, dynamic>>();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(hintText: 'Add a friend by username', isDense: true),
                onSubmitted: (_) => _addByUsername(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _searching ? null : _addByUsername, icon: const Icon(Icons.person_add)),
          ]),
          if (_searchError != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_searchError!, style: TextStyle(color: t.colorScheme.error))),
          const SizedBox(height: 20),
          if (incoming.isNotEmpty) ...[
            const SectionLabel('Requests', icon: Icons.person_add_alt_1),
            HcListGroup(children: [
              for (final r in incoming)
                HcListRow(
                  leading: HcAvatar(name: r['username'] as String? ?? '?'),
                  title: r['username'] as String? ?? 'Player',
                  subtitle: 'Rating ${r['rating'] ?? '—'}',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(Icons.check_rounded, color: context.hc.green), onPressed: () => _respond(r['id'] as String, true)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _respond(r['id'] as String, false)),
                  ]),
                ),
            ]),
            const SizedBox(height: HcSpace.s4),
          ],
          const SectionLabel('Friends', icon: Icons.people_outline),
          if (accepted.isEmpty)
            EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No friends yet',
              body: "Search above or add from a player's profile.",
            )
          else
            HcListGroup(children: [
              for (final f in accepted)
                HcListRow(
                  leading: HcAvatar(name: f['username'] as String? ?? '?'),
                  title: f['username'] as String? ?? 'Player',
                  subtitle: 'Rating ${f['rating'] ?? '—'}',
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => PublicProfileScreen(username: f['username'] as String))),
                  trailing: IconButton(
                    icon: const Icon(Icons.message_outlined),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ConversationScreen(username: f['username'] as String))),
                  ),
                ),
            ]),
          if (outgoing.isNotEmpty) ...[
            const SizedBox(height: HcSpace.s4),
            const SectionLabel('Sent requests', icon: Icons.schedule_send_outlined),
            HcListGroup(children: [
              for (final o in outgoing)
                HcListRow(title: o['username'] as String? ?? 'Player', trailing: Text('Pending', style: HcText.bodySm.copyWith(color: context.hc.ink3))),
            ]),
          ],
        ],
      ),
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/social/feed') as Map<String, dynamic>;
      if (mounted) setState(() => _items = (r['items'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.bolt_rounded,
        title: 'No activity yet',
        body: 'Follow players to see their games and achievements here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HcListGroup(children: [
            for (final it in items)
              HcListRow(
                leading: HcAvatar(name: it['username'] as String? ?? '?'),
                title: it['username'] as String? ?? 'Player',
                subtitle: '${it['type']}',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => PublicProfileScreen(username: it['username'] as String))),
              ),
          ]),
        ],
      ),
    );
  }
}

class _MessagesTab extends StatefulWidget {
  const _MessagesTab();

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  List<Map<String, dynamic>>? _conversations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/social/messages') as Map<String, dynamic>;
      if (mounted) setState(() => _conversations = (r['conversations'] as List).cast<Map<String, dynamic>>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    final conversations = _conversations;
    if (conversations == null) return const Center(child: CircularProgressIndicator());
    if (conversations.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        body: 'Message a friend from their profile to start a conversation.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HcListGroup(children: [
            for (final c in conversations)
              HcListRow(
                leading: HcAvatar(name: c['username'] as String? ?? '?'),
                title: c['username'] as String? ?? 'Player',
                subtitle: c['lastMessage'] as String? ?? '',
                trailing: (c['unread'] as int? ?? 0) > 0 ? HcBadge.count(c['unread'] as int) : null,
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ConversationScreen(username: c['username'] as String)));
                  _load();
                },
              ),
          ]),
        ],
      ),
    );
  }
}
