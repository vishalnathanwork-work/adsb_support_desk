import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/ticket_model.dart';

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
  // BROADCAST HELPERS
  // ═══════════════════════════════════════════════

  Future<void> _notifyMany({
    required List<String> emails,
    required String ticketId,
    required String title,
    required String body,
    required String type,
  }) async {
    final unique = emails.where((e) => e.isNotEmpty).toSet();

    await Future.wait(unique.map((email) => addNotification(
      userId: email,
      ticketId: ticketId,
      title: title,
      body: body,
      type: type,
    )));
  }

  Future<List<String>> _emailsByRole(String role) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .where('is_active', isEqualTo: true)
          .get();

      return snap.docs.map((d) => d['email'] as String).toList();
    } catch (e) {
      print('_emailsByRole($role) error: $e');
      return [];
    }
  }

  Future<List<String>> _emailsByRoles(List<String> roles) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: roles)
          .where('is_active', isEqualTo: true)
          .get();

      return snap.docs.map((d) => d['email'] as String).toList();
    } catch (e) {
      print('_emailsByRoles($roles) error: $e');
      return [];
    }
  }

  Future<List<String>> _getInternalEmails() =>
      _emailsByRoles(['adsb', 'onsite', 'admin']);

  Future<List<String>> _getTTEmails() => _emailsByRole('technician');

  Future<List<String>> _getOnsiteEmails() => _emailsByRole('onsite');

  Future<List<String>> _getAdsbEmails() => _emailsByRole('adsb');

  // ═══════════════════════════════════════════════
  // HIGH-LEVEL EVENT METHODS
  // ═══════════════════════════════════════════════

  /// Ticket created → notify creator + all ADSB support.
  Future<void> onTicketCreated(Ticket ticket) async {
    await addNotification(
      userId: ticket.createdBy,
      ticketId: ticket.id,
      title: 'Ticket Submitted',
      body: 'Your ticket ${ticket.id} has been received.',
      type: 'status_update',
    );

    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'New Ticket',
      body:
      '${ticket.createdByName} created ${ticket.id} — ${ticket.productIssue}',
      type: 'status_update',
    );
  }

  /// ADSB escalated to TT (first internal message sent).
  Future<void> onEscalatedToTT(Ticket ticket) async {
    await addNotification(
      userId: ticket.createdBy,
      ticketId: ticket.id,
      title: 'Issue Being Reviewed',
      body: 'Our team is reviewing your issue.',
      type: 'status_update',
    );

    final ttEmails = await _getTTEmails();
    await _notifyMany(
      emails: ttEmails,
      ticketId: ticket.id,
      title: 'New Ticket Escalated',
      body:
      '${ticket.assignedToName ?? "ADSB"} escalated ${ticket.id} for review.',
      type: 'status_update',
    );
  }

  /// TT replied with advice.
  Future<void> onTTReplied(Ticket ticket) async {
    final internalEmails = await _getInternalEmails();
    await _notifyMany(
      emails: internalEmails,
      ticketId: ticket.id,
      title: 'TT Advice Received',
      body: 'TT has replied on ${ticket.id}. Open the internal chat to view.',
      type: 'status_update',
    );
  }

  /// ADSB sent ticket to on-site queue.
  Future<void> onSentToOnsite(Ticket ticket) async {
    await addNotification(
      userId: ticket.createdBy,
      ticketId: ticket.id,
      title: 'On-Site Visit Scheduled',
      body: 'Our team will attend your site shortly.',
      type: 'schedule',
    );

    final onsiteEmails = await _getOnsiteEmails();
    await _notifyMany(
      emails: onsiteEmails,
      ticketId: ticket.id,
      title: 'New On-Site Job',
      body:
      '${ticket.id} — ${ticket.siteName} · ${ticket.laneName}. Claim it from Jobs.',
      type: 'schedule',
    );

    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Sent to On-Site',
      body: '${ticket.id} has been sent to the on-site queue.',
      type: 'status_update',
    );

    final ttEmails = await _getTTEmails();
    await _notifyMany(
      emails: ttEmails,
      ticketId: ticket.id,
      title: 'On-Site Visit Initiated',
      body: 'ADSB scheduled on-site work for ${ticket.id}.',
      type: 'status_update',
    );
  }

  /// On-site technician claimed the job.
  Future<void> onJobClaimed(Ticket ticket) async {
    await addNotification(
      userId: ticket.createdBy,
      ticketId: ticket.id,
      title: 'Technician On The Way',
      body: 'A technician has been assigned to ${ticket.id}.',
      type: 'schedule',
    );

    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Job Claimed',
      body:
      '${ticket.assignedToName ?? "A technician"} claimed ${ticket.id}.',
      type: 'status_update',
    );
  }

  /// On-site technician completed the work.
  Future<void> onJobCompleted(Ticket ticket) async {
    await addNotification(
      userId: ticket.createdBy,
      ticketId: ticket.id,
      title: 'Issue Resolved',
      body: 'Your issue has been resolved. Please confirm.',
      type: 'resolved',
    );

    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'On-Site Work Completed',
      body: '${ticket.id} has been marked resolved by on-site team.',
      type: 'status_update',
    );

    final ttEmails = await _getTTEmails();
    await _notifyMany(
      emails: ttEmails,
      ticketId: ticket.id,
      title: 'Ticket Resolved',
      body: '${ticket.id} was resolved on-site.',
      type: 'status_update',
    );
  }

  /// ADSB resolved remotely.
  Future<void> onRemoteResolution(Ticket ticket) async {
    await addNotification(
      userId: ticket.createdBy,
      ticketId: ticket.id,
      title: 'Ticket Resolved',
      body: 'Your issue was resolved remotely. Please confirm.',
      type: 'resolved',
    );

    final ttEmails = await _getTTEmails();
    await _notifyMany(
      emails: ttEmails,
      ticketId: ticket.id,
      title: 'Resolved Remotely',
      body: '${ticket.id} was resolved remotely by ADSB.',
      type: 'status_update',
    );
  }

  /// Client confirmed resolution.
  Future<void> onClientConfirmed(Ticket ticket) async {
    final internalEmails = await _getInternalEmails();
    await _notifyMany(
      emails: internalEmails,
      ticketId: ticket.id,
      title: 'Ticket Closed',
      body: '${ticket.id} has been confirmed and closed by the client.',
      type: 'status_update',
    );

    final ttEmails = await _getTTEmails();
    await _notifyMany(
      emails: ttEmails,
      ticketId: ticket.id,
      title: 'Ticket Closed',
      body: '${ticket.id} has been closed.',
      type: 'status_update',
    );
  }

  /// Client reopened the ticket.
  Future<void> onTicketReopened(Ticket ticket) async {
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Ticket Reopened',
      body: 'Client reopened ${ticket.id}. It is back in your queue.',
      type: 'status_update',
    );
  }

  /// Ticket was cancelled by client.
  Future<void> onTicketCancelled(Ticket ticket) async {
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Ticket Cancelled',
      body: 'Client cancelled ${ticket.id}.',
      type: 'status_update',
    );
  }
}