class ChatMessage {
  final String id;
  final String ticketId;
  final String senderEmail;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.ticketId,
    required this.senderEmail,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticketId': ticketId,
    'senderEmail': senderEmail,
    'senderName': senderName,
    'senderRole': senderRole,
    'message': message,
    'sentAt': sentAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    ticketId: json['ticketId'],
    senderEmail: json['senderEmail'],
    senderName: json['senderName'],
    senderRole: json['senderRole'],
    message: json['message'],
    sentAt: DateTime.parse(json['sentAt']),
  );
}