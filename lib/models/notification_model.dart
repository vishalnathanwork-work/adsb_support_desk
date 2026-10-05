class AppNotification {
  final String id;
  final String userId;
  final String ticketId;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.userId,
    required this.ticketId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_email': userId,
    'ticket_id': ticketId,
    'title': title,
    'body': body,
    'type': type,
    'created_at': createdAt.toIso8601String(),
    'is_read': isRead ? 1 : 0,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'].toString(),
        userId: json['user_email'] ?? '',
        ticketId: json['ticket_id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        type: json['type'] ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        isRead: json['is_read'] == 1 || json['is_read'] == true,
      );
}