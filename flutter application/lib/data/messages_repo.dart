import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

/// Messages between the logged-in client and the clinic.
class MessagesRepo {
  MessagesRepo._();

  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  /// Live list of my conversation, oldest first. Updates by itself when the clinic replies.
  static Stream<List<ChatMessage>> myMessages() => _db
      .from('messages')
      .stream(primaryKey: ['message_id'])
      .eq('client_id', _uid)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(ChatMessage.fromMap).toList());

  static Future<void> send(String body) async {
    await _db.from('messages').insert({
      'client_id': _uid,
      'sender_id': _uid,
      'body': body.trim(),
    });
  }

  /// How many clinic messages I haven't read yet.
  static Future<int> unreadCount() async {
    final rows = await _db
        .from('messages')
        .select('message_id')
        .eq('client_id', _uid)
        .neq('sender_id', _uid)
        .isFilter('read_at', null);
    return rows.length;
  }

  /// Mark all clinic messages as read (called when the chat is open).
  static Future<void> markAllRead() async {
    await _db
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('client_id', _uid)
        .neq('sender_id', _uid)
        .isFilter('read_at', null);
  }

  /// Names of vets / receptionists, to show who replied.
  static Future<Map<String, String>> staffNames() async {
    final rows = await _db.from('staff_directory').select('id, full_name');
    return {
      for (final r in rows)
        r['id'] as String: (r['full_name'] as String?) ?? 'Clinic',
    };
  }
}
