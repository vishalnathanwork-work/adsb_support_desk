import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'push_notification_service.dart';

class AppNotificationListener {
  // ─── Singleton ───
  static final AppNotificationListener _instance =
  AppNotificationListener._internal();
  factory AppNotificationListener() => _instance;
  AppNotificationListener._internal();

  final _firestore = FirebaseFirestore.instance;
  final _push = PushNotificationService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;

  String? _currentUserEmail;
  String? _currentUserRole;
  List<String> _currentUserSiteIds = [];

  /// 🆕 The ticket ID the user is currently viewing in the chat screen.
  /// When a chat notification arrives for this ticket, skip it.
  String? _currentViewingTicketId;

  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserRole => _currentUserRole;
  List<String> get currentUserSiteIds =>
      List.unmodifiable(_currentUserSiteIds);
  String? get currentViewingTicketId => _currentViewingTicketId;

  DateTime? _startedAt;
  bool _isRunning = false;

  /// Called by the chat screen when it opens/closes.
  void setViewingTicket(String? ticketId) {
    _currentViewingTicketId = ticketId;
    print('👁️ Notification listener: viewing ticket = ${ticketId ?? "none"}');
  }

  /// Start listening. Call after successful login OR session restore.
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

    await _notifSub?.cancel();

    _notifSub = _firestore
        .collection('notifications')
        .where('user_email', isEqualTo: userEmail)
        .snapshots()
        .listen(
      _onNotificationDocument,
      onError: (err) {
        print('Notification listener error: $err');
      },
    );
  }

  /// Stop listening. Call on every logout.
  Future<void> stop() async {
    _isRunning = false;
    await _notifSub?.cancel();
    _notifSub = null;
    _currentUserEmail = null;
    _currentUserRole = null;
    _currentUserSiteIds = [];
    _currentViewingTicketId = null;
    _startedAt = null;
  }

  // ─────────────────────────────────────────────────────
  // NOTIFICATION HANDLER
  // ─────────────────────────────────────────────────────

  void _onNotificationDocument(
      QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
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
      final type = data['type'] ?? 'general';

      // 🆕 SUPPRESS chat notifications when user is viewing that chat
      if (type == 'chat_message' &&
          ticketId.isNotEmpty &&
          ticketId == _currentViewingTicketId) {
        print(
          '🔕 Suppressed chat notification (user is viewing $ticketId)',
        );
        continue;
      }

      _push.showLocal(
        title: title,
        body: body,
        ticketId: ticketId,
        type: type,
      );
    }
  }
}