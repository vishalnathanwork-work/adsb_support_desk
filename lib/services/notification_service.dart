import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final _col = FirebaseFirestore.instance.collection('notifications');

  // ═══════════════════════════════════════════════
  // LOW-LEVEL API
  // ═══════════════════════════════════════════════

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

  Stream<List<AppNotification>> streamMyNotifications(String userEmail) {
    return _col
        .where('user_email', isEqualTo: userEmail)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppNotification.fromJson({
        ...doc.data(),
        'id': doc.id,
      }))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> addNotification({
    required String userId,
    required String ticketId,
    required String title,
    required String body,
    required String type,
  }) async {
    if (userId.isEmpty) return;
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

  // ═══════════════════════════════════════════════
  // APPROVAL NOTIFICATIONS (kept client-side for
  // a friendlier message; Cloud Function skips these)
  // ═══════════════════════════════════════════════

  Future<void> onUserApproved({
    required String userEmail,
    required String userName,
  }) async {
    await addNotification(
      userId: userEmail,
      ticketId: '',
      title: 'Account Approved',
      body: 'Welcome, $userName! Your account has been approved. '
          'You can now log in and use the app.',
      type: 'user_approved',
    );
  }

  Future<void> onUserRejected({
    required String userEmail,
    required String userName,
  }) async {
    await addNotification(
      userId: userEmail,
      ticketId: '',
      title: 'Registration Declined',
      body: 'Hi $userName, your registration request was not approved. '
          'Contact ADSB support for assistance.',
      type: 'user_rejected',
    );
  }
}