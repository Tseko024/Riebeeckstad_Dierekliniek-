/// One message between the clinic and the logged-in client (public.messages).
class ChatMessage {
  final String id;
  final String clientId;
  final String? senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.clientId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['message_id'] as String,
        clientId: m['client_id'] as String,
        senderId: m['sender_id'] as String?,
        body: (m['body'] ?? '') as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        readAt: m['read_at'] == null
            ? null
            : DateTime.parse(m['read_at'] as String),
      );

  /// Sent by the client (not the clinic).
  bool get fromMe => senderId == clientId;

  /// Time at the clinic (South Africa, UTC+2).
  DateTime get clinicTime => createdAt.toUtc().add(const Duration(hours: 2));
}
