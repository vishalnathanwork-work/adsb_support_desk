import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'session_service.dart';

class SessionGuardService {
  static final SessionGuardService _instance =
  SessionGuardService._internal();
  factory SessionGuardService() => _instance;
  SessionGuardService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _currentSessionId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  void Function()? onSessionInvalidated;

  String? get currentSessionId => _currentSessionId;

  String _generateSessionId() {
    final uid = _auth.currentUser?.uid ?? 'anon';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = DateTime.now().microsecondsSinceEpoch % 1000000;
    return '${uid}_${ts}_$rand';
  }

  /// Called right after successful login.
  Future<void> registerSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final sessionId = _generateSessionId();
    _currentSessionId = sessionId;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'active_session': sessionId,
        'active_session_at': FieldValue.serverTimestamp(),
      });

      // ⭐ Persist locally for Remember Me restore
      await SessionService().saveSessionId(sessionId);

      debugPrint('SessionGuard: session registered $sessionId');
      _startListener(user.uid, sessionId);
    } catch (e) {
      debugPrint('SessionGuard: register failed: $e');
    }
  }

  /// Called on splash restore. Verifies the local sessionId still
  /// matches the remote active_session.
  ///
  /// Returns true if this device is still the active session.
  Future<bool> verifyRestoredSession(String? localSessionId) async {
    if (localSessionId == null || localSessionId.isEmpty) {
      debugPrint('SessionGuard: no local sessionId — cannot verify');
      return false;
    }

    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final remoteSession = doc.data()?['active_session'] as String?;

      if (remoteSession == localSessionId) {
        _currentSessionId = localSessionId;
        debugPrint('SessionGuard: session verified ✅');
        return true;
      }

      debugPrint(
        'SessionGuard: session MISMATCH '
            '(local=$localSessionId, remote=$remoteSession) — '
            'another device took over',
      );
      return false;
    } catch (e) {
      debugPrint('SessionGuard: verifyRestoredSession error: $e');
      return false;
    }
  }

  /// Re-attach the listener using a verified sessionId.
  Future<void> restoreListener(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentSessionId = sessionId;
    _startListener(user.uid, sessionId);
  }

  void _startListener(String uid, String ourSessionId) {
    _sub?.cancel();
    _sub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final remoteSession = data['active_session'] as String?;

        if (remoteSession != null &&
            remoteSession.isNotEmpty &&
            remoteSession != ourSessionId) {
          debugPrint(
            'SessionGuard: session mismatch '
                '(remote=$remoteSession, ours=$ourSessionId) — signing out',
          );
          _handleInvalidation();
        }
      },
      onError: (err) {
        debugPrint('SessionGuard: listener error: $err');
      },
    );
  }

  Future<void> _handleInvalidation() async {
    await _sub?.cancel();
    _sub = null;
    _currentSessionId = null;

    try {
      onSessionInvalidated?.call();
    } catch (e) {
      debugPrint('SessionGuard: onSessionInvalidated error: $e');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('SessionGuard: signOut error: $e');
    }
  }

  Future<void> clearSession() async {
    final user = _auth.currentUser;
    final ourSessionId = _currentSessionId;

    await _sub?.cancel();
    _sub = null;
    _currentSessionId = null;

    if (user == null || ourSessionId == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final remote = doc.data()?['active_session'] as String?;
      if (remote == ourSessionId) {
        await _firestore.collection('users').doc(user.uid).update({
          'active_session': FieldValue.delete(),
          'active_session_at': FieldValue.delete(),
        });
      }
    } catch (e) {
      debugPrint('SessionGuard: clearSession error: $e');
    }
  }
}