import '../models/notification_model.dart';

class NotificationService {
  static final List<AppNotification> _mockNotifications = [
    AppNotification(
      id: 'NOTIF-001',
      userId: 'client@adsb.com',
      ticketId: 'TICK-1001',
      title: 'Welcome to ADSB Support Desk',
      body: 'Your account is ready. Create a ticket if you experience any equipment issues.',
      type: 'status_update',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
  ];

  Future<List<AppNotification>> getMyNotifications(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockNotifications
        .where((n) => n.userId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addNotification({
    required String userId,
    required String ticketId,
    required String title,
    required String body,
    required String type,
  }) async {
    final newNotif = AppNotification(
      id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      ticketId: ticketId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
    );
    _mockNotifications.insert(0, newNotif);
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _mockNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _mockNotifications[index].isRead = true;
    }
  }
}
