import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/messages_repo.dart';
import '../models/chat_message.dart';
import '../services/message_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Chat with the clinic. New clinic messages appear instantly.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final Stream<List<ChatMessage>> _stream;
  Map<String, String> _staff = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    MessageNotifier.instance.chatOpen = true;
    _stream = MessagesRepo.myMessages();
    MessagesRepo.staffNames().then((s) {
      if (mounted) setState(() => _staff = s);
    }).catchError((_) {});
    _markRead();
  }

  @override
  void dispose() {
    MessageNotifier.instance.chatOpen = false;
    MessageNotifier.instance.refresh();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await MessagesRepo.markAllRead();
      MessageNotifier.instance.unread.value = 0;
    } catch (e) {
      debugPrint('Mark read error: $e');
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await MessagesRepo.send(body);
      _text.clear();
    } on PostgrestException catch (e) {
      _error(e.message);
    } catch (e) {
      _error(
          'Could not send the message. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _error(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: AppColors.red),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  String _when(DateTime t) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 2));
    final time = '${_two(t.hour)}:${_two(t.minute)}';
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? time : '${t.day} ${_months[t.month - 1]} $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'Could not load your messages. Please try again later.',
                            textAlign: TextAlign.center),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snap.data!;

                  // New clinic message arrived while the chat is open → mark it read.
                  if (messages.any((m) => !m.fromMe && m.readAt == null)) {
                    _markRead();
                  }
                  _scrollToBottom();

                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline,
                                size: 48, color: AppColors.navy),
                            const SizedBox(height: 12),
                            Text('No messages yet',
                                style: AppTheme.heading(size: 20)),
                            const SizedBox(height: 6),
                            const Text(
                              'Send the clinic a message about your pet or booking.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _bubble(messages[i]),
                  );
                },
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.fromMe;
    final who =
        mine ? 'You' : (_staff[m.senderId] ?? 'Riebeeckstad Dierekliniek');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.body,
                style: TextStyle(
                    color: mine ? Colors.white : AppColors.textDark,
                    fontSize: 15)),
            const SizedBox(height: 3),
            Text(
              '$who · ${_when(m.clinicTime)}',
              style: TextStyle(
                  color: mine ? Colors.white70 : Colors.black45, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF2F3F8),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: AppColors.red),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
