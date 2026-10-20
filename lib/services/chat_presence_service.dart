import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Tracks which ticket chat the current user is actively viewing.
/// Used by the Cloud Function to suppress notifications for
/// users who are already in the chat.
class ChatPresenceService {
  final _col = FirebaseFirestore.instance.collection('chat_viewers');
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;

  /// Mark this user as viewing a specific ticket chat.
  /// Call when the chat screen is opened.
  Future<void> enterChat(String ticketId) async {
    final uid = _uid;
    final email = _email;
    if (uid == null || email == null) return;

    try {
      await _col.doc(uid).set({
        'user_email': email,
        'ticket_id': ticketId,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('enterChat error: $e');
    }
  }

  /// Clear this user's viewing state.
  /// Call when the chat screen is closed.
  Future<void> exitChat() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _col.doc(uid).delete();
    } catch (e) {
      print('exitChat error: $e');
    }
  }
}