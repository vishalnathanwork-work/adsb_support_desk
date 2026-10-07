import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String ticketId;
  final String channel; // 'ticket' | 'internal'
  final String senderEmail;
  final String senderName;
  final String senderRole;
  final String message;
  final bool isSystem;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.ticketId,
    required this.channel,
    required this.senderEmail,
    required this.senderName,
    required this.senderRole,
    required this.message,
    this.isSystem = false,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticket_id': ticketId,
    'channel': channel,
    'sender_email': senderEmail,
    'sender_name': senderName,
    'sender_role': senderRole,
    'message': message,
    'is_system': isSystem,
    'sent_at': sentAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    ticketId: json['ticket_id'] ?? '',
    channel: json['channel'] ?? 'ticket',
    senderEmail: json['sender_email'] ?? '',
    senderName: json['sender_name'] ?? '',
    senderRole: json['sender_role'] ?? '',
    message: json['message'] ?? '',
    isSystem: json['is_system'] == true,
    sentAt: json['sent_at'] is Timestamp
        ? (json['sent_at'] as Timestamp).toDate()
        : DateTime.now(),
  );
}