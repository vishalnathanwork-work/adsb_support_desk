import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
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

  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserRole => _currentUserRole;
  List<String> get currentUserSiteIds => List.unmodifiable(_currentUserSiteIds);

  DateTime? _startedAt;
  bool _isRunning = false;

  /// Start listening. Call after successful login OR session restore.
  Future<void> start({
    required String userEmail,
    required String userRole,
    required List<String> userSiteIds,
  }) async {
    if (_isRunning) {
      // Already running — just update context
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

    // Cancel any prior subscription defensively
    await _notifSub?.cancel();

    // Listen only to notifications addressed to this user.
    // Firestore security rules enforce the read on this query.
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

    // Cancel subscription — prevents duplicate listeners on re-login
    await _notifSub?.cancel();
    _notifSub = null;

    _currentUserEmail = null;
    _currentUserRole = null;
    _currentUserSiteIds = [];
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
      debugPrint(
        '🔔 Notification change: ${change.type} | id=${change.doc.id}',
      );

      if (change.type != DocumentChangeType.added) continue;

      final data = change.doc.data();
      if (data == null) continue;

      final createdAt = data['created_at'];
      debugPrint('  created_at = $createdAt (${createdAt.runtimeType})');

      if (createdAt is Timestamp) {
        if (_startedAt != null &&
            createdAt.toDate().isBefore(_startedAt!)) {
          debugPrint('  ⏭️ Skipped — predates listener start');
          continue;
        }
      } else if (createdAt != null) {
        debugPrint('  ⏭️ Skipped — created_at not Timestamp');
        continue;
      }

      final title = data['title'] ?? 'Update';
      final body = data['body'] ?? '';
      final ticketId = data['ticket_id'] ?? '';

      debugPrint('  ✅ Showing popup: $title / $body');

      _push.showLocal(
        title: title,
        body: body,
        ticketId: ticketId,
      );
    }
  }
}