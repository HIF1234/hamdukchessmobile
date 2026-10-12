import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';

/// A direct-message thread with one player (GET/POST /social/messages/{username}).
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.username});
  final String username;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<Map<String, dynamic>>? _messages;
  String? _otherId;
  String? _error;
  bool _sending = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/social/messages/${widget.username}') as Map<String, dynamic>;
      final other = r['other'] as Map?;
      if (!mounted) return;
      setState(() {
        _otherId = other?['id'] as String?;
        _messages = (r['messages'] as List).cast<Map<String, dynamic>>();
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final otherId = _otherId;
    if (text.isEmpty || otherId == null) return;
    setState(() => _sending = true);
    try {
      await Api.instance.post('/social/messages/send', {'recipientId': otherId, 'content': text});
      _controller.clear();
      await _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final messages = _messages;
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: Column(children: [
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : messages == null
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? const Center(child: Text('No messages yet. Say hi!'))
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final m = messages[messages.length - 1 - i];
                            final mine = m['sender_id'] == myId;
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: mine ? t.colorScheme.primary : t.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  m['content'] as String,
                                  style: TextStyle(color: mine ? t.colorScheme.onPrimary : t.colorScheme.onSurface),
                                ),
                              ),
                            );
                          },
                        ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'Message…', isDense: true),
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
