import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final _col = FirebaseFirestore.instance.collection('notifications');

  Future<List<AppNotification>> getMyNotifications(String userEmail) async {
    try {
      final snapshot = await _col
          .where('user_email', isEqualTo: userEmail)
          .get();

      final list = snapshot.docs
          .map((doc) => AppNotification.fromJson({
        ...doc.data(),
        'id': doc.id,
      }))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      print('getMyNotifications error: $e');
      return [];
    }
  }

  Future<void> addNotification({
    required String userId,
    required String ticketId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _col.add({
        'user_email': userId,
        'ticket_id': ticketId,
        'title': title,
        'body': body,
        'type': type,
        'is_read': 0,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('addNotification error: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _col.doc(id).update({'is_read': 1});
    } catch (e) {
      print('markAsRead error: $e');
    }
  }
}