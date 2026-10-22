import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Tracks which ticket chat the current user is actively viewing.
/// Refreshes every minute so entries don't go stale.
class ChatPresenceService {
  final _col = FirebaseFirestore.instance.collection('chat_viewers');
  final _auth = FirebaseAuth.instance;

  Timer? _refreshTimer;
  String? _currentTicketId;

  String? get _uid => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;

  /// Mark this user as viewing a specific ticket chat.
  /// Starts a periodic refresh to keep the entry alive.
  Future<void> enterChat(String ticketId) async {
    final uid = _uid;
    final email = _email;
    if (uid == null || email == null) return;

    _currentTicketId = ticketId;

    // Write immediately
    await _writePresence(uid, email, ticketId);

    // Refresh every 60 seconds
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
          (_) {
        final tid = _currentTicketId;
        final u = _uid;
        final e = _email;
        if (tid != null && u != null && e != null) {
          _writePresence(u, e, tid);
        }
      },
    );
  }

  Future<void> _writePresence(
      String uid,
      String email,
      String ticketId,
      ) async {
    try {
      await _col.doc(uid).set({
        'user_email': email,
        'ticket_id': ticketId,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('_writePresence error: $e');
    }
  }

  /// Clear this user's viewing state.
  Future<void> exitChat() async {
    final uid = _uid;
    if (uid == null) return;

    _refreshTimer?.cancel();
    _refreshTimer = null;
    _currentTicketId = null;

    try {
      await _col.doc(uid).delete();
    } catch (e) {
      print('exitChat error: $e');
    }
  }
}