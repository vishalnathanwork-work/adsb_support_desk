import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final _col = FirebaseFirestore.instance.collection('tickets');

  // ═══════════════════════════════════════════════
  // REASSIGN
  // NOTE: Notification handled by Cloud Function
  // notifyTicketUpdated (assignee_changed).
  // ═══════════════════════════════════════════════

  Future<bool> reassign({
    required String ticketId,
    required String assigneeEmail,
    required String assigneeName,
    required String reason,
    required String adminEmail,
  }) async {
    try {
      final doc = await _col.doc(ticketId).get();
      if (!doc.exists) return false;

      final previousAssignee =
          doc.data()?['assigned_to'] as String? ?? '';

      await _col.doc(ticketId).update({
        'assigned_to': assigneeEmail,
        'assigned_to_name': assigneeName,
        'last_admin_action': {
          'action': 'reassign',
          'reason': reason,
          'by': adminEmail,
          'from': previousAssignee,
          'to': assigneeEmail,
          'at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('reassign error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // STATUS OVERRIDE
  // NOTE: Notification handled by Cloud Function
  // notifyTicketUpdated (status_changed).
  // ═══════════════════════════════════════════════

  Future<bool> overrideStatus({
    required String ticketId,
    required String newStatus,
    required String reason,
    required String adminEmail,
  }) async {
    try {
      final doc = await _col.doc(ticketId).get();
      if (!doc.exists) return false;

      final oldStatus = doc.data()?['status'] as String? ?? '';

      if (oldStatus == newStatus) {
        print('Status already $newStatus — skipping');
        return true;
      }

      final fields = <String, dynamic>{
        'status': newStatus,
        'last_admin_action': {
          'action': 'status_override',
          'from': oldStatus,
          'to': newStatus,
          'reason': reason,
          'by': adminEmail,
          'at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      };

      switch (newStatus) {
        case 'verified':
          fields['verified_at'] = FieldValue.serverTimestamp();
          break;
        case 'pending_onsite':
          fields['escalated_at'] = FieldValue.serverTimestamp();
          break;
        case 'in_progress':
          fields['adsb_pickup_at'] = FieldValue.serverTimestamp();
          break;
        case 'resolved':
          fields['resolved_at'] = FieldValue.serverTimestamp();
          break;
        case 'closed':
          fields['client_confirmed_at'] = FieldValue.serverTimestamp();
          break;
        case 'reopened':
          fields['reopened_at'] = FieldValue.serverTimestamp();
          fields['assigned_to'] = null;
          fields['assigned_to_name'] = null;
          break;
        case 'cancelled':
          fields['cancelled_at'] = FieldValue.serverTimestamp();
          break;
      }

      await _col.doc(ticketId).update(fields);
      return true;
    } catch (e) {
      print('overrideStatus error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE
  // NOTE: Notification handled by Cloud Function
  // notifyTicketDeleted (onDocumentDeleted).
  // ═══════════════════════════════════════════════

  Future<bool> deleteTicket(String ticketId) async {
    try {
      final chatSnap = await FirebaseFirestore.instance
          .collection('chat_messages')
          .where('ticket_id', isEqualTo: ticketId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in chatSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_col.doc(ticketId));
      await batch.commit();
      return true;
    } catch (e) {
      print('deleteTicket error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // FETCH CANDIDATES
  // ═══════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAssignableUsers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: [
        'adsb',
        'technician',
        'onsite',
        'admin',
      ])
          .where('is_active', isEqualTo: true)
          .get();

      return snap.docs
          .map((d) => <String, dynamic>{'uid': d.id, ...d.data()})
          .toList();
    } catch (e) {
      print('getAssignableUsers error: $e');
      return [];
    }
  }
}