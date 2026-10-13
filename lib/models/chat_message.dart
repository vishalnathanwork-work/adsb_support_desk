import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String ticketId;
  final String channel;
  final String senderEmail;
  final String senderName;
  final String senderRole;
  final String message;
  final bool isSystem;
  final List<String> imageUrls;
  final List<String> attachmentUrls;      // NEW — documents/any files
  final List<String> attachmentNames;     // NEW — display names
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
    this.imageUrls = const [],
    this.attachmentUrls = const [],
    this.attachmentNames = const [],
    required this.sentAt,
  });

  String get displayRole {
    switch (senderRole) {
      case 'owner':
        return 'Site Owner';
      case 'operator':
        return 'Site Operator';
      case 'adsb':
      case 'technician':
      case 'onsite':
      case 'admin':
        return 'ADSB Support';
      case 'system':
        return 'System';
      default:
        return 'User';
    }
  }

  bool get isInternalSender =>
      senderRole == 'adsb' ||
          senderRole == 'technician' ||
          senderRole == 'onsite' ||
          senderRole == 'admin';

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticket_id': ticketId,
    'channel': channel,
    'sender_email': senderEmail,
    'sender_name': senderName,
    'sender_role': senderRole,
    'message': message,
    'is_system': isSystem,
    'image_urls': imageUrls,
    'attachment_urls': attachmentUrls,
    'attachment_names': attachmentNames,
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
    imageUrls: _stringList(json['image_urls']),
    attachmentUrls: _stringList(json['attachment_urls']),
    attachmentNames: _stringList(json['attachment_names']),
    sentAt: json['sent_at'] is Timestamp
        ? (json['sent_at'] as Timestamp).toDate()
        : DateTime.now(),
  );

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return value.isEmpty ? [] : [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}