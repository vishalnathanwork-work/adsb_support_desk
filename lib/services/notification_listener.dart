import 'package:cloud_firestore/cloud_firestore.dart';
import 'push_notification_service.dart';

class AppNotificationListener {
  // Singleton
  static final AppNotificationListener _instance =
  AppNotificationListener._internal();
  factory AppNotificationListener() => _instance;
  AppNotificationListener._internal();

  final _firestore = FirebaseFirestore.instance;
  final _push = PushNotificationService();

  String? _currentUserEmail;
  DateTime? _startedAt;
  bool _isRunning = false;

  /// Start listening. Call after successful login.
  void start(String userEmail) {
    if (_isRunning) {
      _currentUserEmail = userEmail;
      return;
    }

    _isRunning = true;
    _currentUserEmail = userEmail;
    _startedAt = DateTime.now();

    // Listen to new chat messages
    _firestore
        .collection('chat_messages')
        .orderBy('sent_at', descending: false)
        .snapshots()
        .listen(_onChatMessage);

    // Listen to new notifications addressed to me
    _firestore
        .collection('notifications')
        .where('user_email', isEqualTo: userEmail)
        .snapshots()
        .listen(_onNotificationDocument);
  }

  /// Stop listening. Call on logout.
  void stop() {
    _isRunning = false;
    _currentUserEmail = null;
    _startedAt = null;
  }

  // ─────────────────────────────────────────────────────
  // HANDLERS
  // ─────────────────────────────────────────────────────

  void _onChatMessage(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_isRunning) return;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;

      final data = change.doc.data();
      if (data == null) continue;

      final senderEmail = data['sender_email'] as String? ?? '';

      if (senderEmail == _currentUserEmail) continue;

      final sentAt = data['sent_at'];
      if (sentAt is Timestamp) {
        if (_startedAt != null && sentAt.toDate().isBefore(_startedAt!)) {
          continue;
        }
      } else {
        continue;
      }

      final senderName = data['sender_name'] ?? 'Someone';
      final message = data['message'] ?? '';
      final ticketId = data['ticket_id'] ?? '';

      _push.showLocal(
        title: '$senderName sent a message',
        body: message.length > 60 ? '${message.substring(0, 60)}…' : message,
        ticketId: ticketId,
      );
    }
  }

  void _onNotificationDocument(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_isRunning) return;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;

      final data = change.doc.data();
      if (data == null) continue;

      final createdAt = data['created_at'];
      if (createdAt is Timestamp) {
        if (_startedAt != null && createdAt.toDate().isBefore(_startedAt!)) {
          continue;
        }
      } else {
        continue;
      }

      final title = data['title'] ?? 'Update';
      final body = data['body'] ?? '';
      final ticketId = data['ticket_id'] ?? '';

      _push.showLocal(
        title: title,
        body: body,
        ticketId: ticketId,
      );
    }
  }
}