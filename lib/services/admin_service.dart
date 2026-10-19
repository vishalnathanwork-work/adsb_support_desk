import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AdminService {
  final _col = FirebaseFirestore.instance.collection('tickets');
  final _notif = NotificationService();

  // ═══════════════════════════════════════════════
  // REASSIGN
  // ═══════════════════════════════════════════════

  Future<bool> reassign({
    required String ticketId,
    required String assigneeEmail,
    required String assigneeName,
    required String reason,
    required String adminEmail,
  }) async {
    try {
      // Get current ticket (for notifications + audit)
      final doc = await _col.doc(ticketId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final previousAssignee = data['assigned_to'] as String? ?? '';
      final ticketCreatedBy = data['created_by'] as String? ?? '';

      // Update ticket
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

      // ─── Notify: new assignee ───
      try {
        await _notif.addNotification(
          userId: assigneeEmail,
          ticketId: ticketId,
          title: 'Ticket Assigned to You',
          body: '$ticketId was reassigned to you by admin. '
              'Reason: $reason',
          type: 'assignment',
        );
      } catch (e) {
        print('notif assignee failed: $e');
      }

      // ─── Notify: previous assignee (if different) ───
      if (previousAssignee.isNotEmpty &&
          previousAssignee != assigneeEmail) {
        try {
          await _notif.addNotification(
            userId: previousAssignee,
            ticketId: ticketId,
            title: 'Ticket Reassigned',
            body: '$ticketId is no longer assigned to you. '
                'New assignee: $assigneeName',
            type: 'assignment',
          );
        } catch (e) {
          print('notif previous assignee failed: $e');
        }
      }

      // ─── Notify: ticket creator ───
      if (ticketCreatedBy.isNotEmpty &&
          ticketCreatedBy != assigneeEmail) {
        try {
          await _notif.addNotification(
            userId: ticketCreatedBy,
            ticketId: ticketId,
            title: 'Ticket Update',
            body: 'Your ticket $ticketId has been reassigned to a '
                'different team member.',
            type: 'status_update',
          );
        } catch (e) {
          print('notif creator failed: $e');
        }
      }

      return true;
    } catch (e) {
      print('reassign error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // STATUS OVERRIDE
  // ═══════════════════════════════════════════════

  Future<bool> overrideStatus({
    required String ticketId,
    required String newStatus,
    required String reason,
    required String adminEmail,
  }) async {
    try {
      // Get current ticket
      final doc = await _col.doc(ticketId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final oldStatus = data['status'] as String? ?? '';
      final ticketCreatedBy = data['created_by'] as String? ?? '';
      final assignedTo = data['assigned_to'] as String? ?? '';

      if (oldStatus == newStatus) {
        print('Status already $newStatus — skipping');
        return true;
      }

      // Build update
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

      // Timestamp milestones
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

      // ─── Notify: ticket creator ───
      if (ticketCreatedBy.isNotEmpty) {
        try {
          await _notif.addNotification(
            userId: ticketCreatedBy,
            ticketId: ticketId,
            title: 'Ticket Status Updated',
            body: '$ticketId status changed to ${_statusLabel(newStatus)} '
                'by admin.',
            type: 'status_update',
          );
        } catch (e) {
          print('notif creator failed: $e');
        }
      }

      // ─── Notify: assignee (if different from creator) ───
      if (assignedTo.isNotEmpty && assignedTo != ticketCreatedBy) {
        try {
          await _notif.addNotification(
            userId: assignedTo,
            ticketId: ticketId,
            title: 'Ticket Status Overridden',
            body: '$ticketId status changed from '
                '${_statusLabel(oldStatus)} to ${_statusLabel(newStatus)}.',
            type: 'status_update',
          );
        } catch (e) {
          print('notif assignee failed: $e');
        }
      }

      return true;
    } catch (e) {
      print('overrideStatus error: $e');
      return false;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Verification';
      case 'verified':
        return 'In Review';
      case 'pending_onsite':
        return 'On-Site Queued';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'reopened':
        return 'Reopened';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE
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

  /// Returns internal team members (adsb/technician/onsite/admin).
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