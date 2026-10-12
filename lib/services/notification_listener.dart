import 'package:cloud_firestore/cloud_firestore.dart';
import 'push_notification_service.dart';

class AppNotificationListener {
  static final AppNotificationListener _instance =
  AppNotificationListener._internal();
  factory AppNotificationListener() => _instance;
  AppNotificationListener._internal();

  final _firestore = FirebaseFirestore.instance;
  final _push = PushNotificationService();

  String? _currentUserEmail;
  String? _currentUserRole;
  List<String> _currentUserSiteIds = [];
  DateTime? _startedAt;
  bool _isRunning = false;

  Future<void> start({
    required String userEmail,
    required String userRole,
    required List<String> userSiteIds,
  }) async {
    if (_isRunning) {
      _currentUserEmail = userEmail;
      _currentUserRole = userRole;
      _currentUserSiteIds = userSiteIds;
      return;
    }

    _isRunning = true;
    _currentUserEmail = userEmail;
    _currentUserRole = userRole;
    _currentUserSiteIds = userSiteIds;
    _startedAt = DateTime.now();

    // ── Chat messages ──
    // Skipped for on-site users: they only get the "new job" notification.
    if (userRole != 'onsite') {
      _firestore
          .collection('chat_messages')
          .orderBy('sent_at', descending: false)
          .snapshots()
          .listen(_onChatMessage);
    }

    // ── Notification documents (fan-out from NotificationService) ──
    // Every role uses this path; NotificationService decides who to write to.
    _firestore
        .collection('notifications')
        .where('user_email', isEqualTo: userEmail)
        .snapshots()
        .listen(_onNotificationDocument);
  }

  void stop() {
    _isRunning = false;
    _currentUserEmail = null;
    _currentUserRole = null;
    _currentUserSiteIds = [];
    _startedAt = null;
  }

  // ─────────────────────────────────────────────────────
  // CHAT MESSAGE HANDLER
  // (only runs for non-onsite roles)
  // ─────────────────────────────────────────────────────

  Future<void> _onChatMessage(
      QuerySnapshot<Map<String, dynamic>> snapshot) async {
    if (!_isRunning) return;
    if (_currentUserEmail == null) return;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;

      final data = change.doc.data();
      if (data == null) continue;

      final senderEmail = data['sender_email'] as String? ?? '';
      if (senderEmail == _currentUserEmail) continue;

      final isSystem = data['is_system'] == true;
      if (isSystem) continue;

      final sentAt = data['sent_at'];
      if (sentAt is Timestamp) {
        if (_startedAt != null && sentAt.toDate().isBefore(_startedAt!)) {
          continue;
        }
      } else {
        continue;
      }

      final ticketId = data['ticket_id'] as String? ?? '';
      if (ticketId.isEmpty) continue;

      // ── Role-based gate for chat notifications ──
      final role = _currentUserRole ?? '';

      // ADSB / TT / Admin: always notified of chat
      // Owner / Operator: only if the ticket is at their site
      // On-site: never reaches here (listener skipped)
      bool shouldNotify = false;

      if (role == 'adsb' || role == 'technician' || role == 'admin') {
        shouldNotify = true;
      } else if (role == 'owner' || role == 'operator') {
        try {
          final doc =
          await _firestore.collection('tickets').doc(ticketId).get();
          if (doc.exists) {
            final siteId = doc.data()?['site_id'] as String? ?? '';
            shouldNotify = _currentUserSiteIds.contains(siteId);
          }
        } catch (e) {
          print('_onChatMessage site check error: $e');
        }
      }

      if (!shouldNotify) continue;

      final senderName = data['sender_name'] ?? 'Someone';
      final message = data['message'] ?? '';

      await _push.showLocal(
        title: '$senderName sent a message',
        body: message.length > 60
            ? '${message.substring(0, 60)}…'
            : message,
        ticketId: ticketId,
      );
    }
  }

  // ─────────────────────────────────────────────────────
  // NOTIFICATION DOCUMENT HANDLER
  // ─────────────────────────────────────────────────────

  void _onNotificationDocument(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_isRunning) return;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;

      final data = change.doc.data();
      if (data == null) continue;

      final createdAt = data['created_at'];
      if (createdAt is Timestamp) {
        if (_startedAt != null &&
            createdAt.toDate().isBefore(_startedAt!)) {
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