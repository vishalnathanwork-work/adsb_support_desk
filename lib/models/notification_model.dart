class AppNotification {
  final String id;
  final String userId;      // recipient email
  final String ticketId;    // linked ticket
  final String title;
  final String body;
  final String type;        // status_update | comment | schedule | resolved
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
    'userId': userId,
    'ticketId': ticketId,
    'title': title,
    'body': body,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        userId: json['userId'],
        ticketId: json['ticketId'],
        title: json['title'],
        body: json['body'],
        type: json['type'],
        createdAt: DateTime.parse(json['createdAt']),
        isRead: json['isRead'] ?? false,
      );
}