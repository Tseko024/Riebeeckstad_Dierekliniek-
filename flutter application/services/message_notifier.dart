import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/messages_repo.dart';
import '../routes.dart';
import '../theme/app_colors.dart';

/// Listens for new clinic messages while the app is open:
/// keeps the unread count (for the badge) and shows a pop-up banner.
class MessageNotifier {
  MessageNotifier._();
  static final MessageNotifier instance = MessageNotifier._();

  /// Add both keys to MaterialApp (see main.dart).
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Number of unread clinic messages (the red badge).
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  /// True while the Messages screen is open (no banner needed then).
  bool chatOpen = false;

  SupabaseClient get _db => Supabase.instance.client;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;
  String? _uid;

  /// Call once in main(), after Supabase.initialize().
  void start() {
    _listenFor(_db.auth.currentUser?.id);
    _authSub ??= _db.auth.onAuthStateChange.listen((data) {
      _listenFor(data.session?.user.id);
    });
  }

  Future<void> _listenFor(String? uid) async {
    if (uid == _uid) return; // same user (e.g. token refresh)
    _uid = uid;

    if (_channel != null) {
      await _db.removeChannel(_channel!);
      _channel = null;
    }
    unread.value = 0;
    if (uid == null) return; // logged out

    await refresh();
    _channel = _db
        .channel('client-messages-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'client_id',
            value: uid,
          ),
          callback: _onNewMessage,
        )
        .subscribe();
  }

  /// Re-count unread messages from the database.
  Future<void> refresh() async {
    if (_uid == null) return;
    try {
      unread.value = await MessagesRepo.unreadCount();
    } catch (e) {
      debugPrint('Unread count error: $e');
    }
  }

  void _onNewMessage(PostgresChangePayload payload) {
    final row = payload.newRecord;
    if (row['sender_id'] == _uid) return; // my own message
    if (chatOpen) return; // already looking at the chat

    unread.value = unread.value + 1;

    final body = (row['body'] ?? '').toString();
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.chat_bubble, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New message from the clinic:\n$body',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () =>
                navigatorKey.currentState?.pushNamed(Routes.messages),
          ),
        ),
      );
  }
}
