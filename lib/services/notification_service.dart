import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  Future<List<AppNotification>> getMyNotifications(String userEmail) async {
    final response = await ApiClient.get('notifications.php', query: {
      'action': 'mine',
      'email': userEmail,
    });

    if (response['success'] == true && response['notifications'] != null) {
      return (response['notifications'] as List)
          .map((j) => AppNotification.fromJson(j))
          .toList();
    }
    return [];
  }

  Future<int> getUnreadCount(String userEmail) async {
    final all = await getMyNotifications(userEmail);
    return all.where((n) => !n.isRead).length;
  }

  Future<void> addNotification({
    required String userId,
    required String ticketId,
    required String title,
    required String body,
    required String type,
  }) async {
    await ApiClient.post('notifications.php', {
      'user_email': userId,
      'ticket_id': ticketId,
      'title': title,
      'body': body,
      'type': type,
    });
  }
}