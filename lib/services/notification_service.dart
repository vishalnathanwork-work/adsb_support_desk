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

  Stream<List<AppNotification>> streamMyNotifications(String userEmail) {
    return _col
        .where('user_email', isEqualTo: userEmail)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppNotification.fromJson({
        ...doc.data(),
        'id': doc.id,
      }))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
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
  // HELPERS
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

  Future<List<String>> _getAdsbEmails() => _emailsByRole('adsb');
  Future<List<String>> _getTTEmails() => _emailsByRole('technician');
  Future<List<String>> _getOnsiteEmails() => _emailsByRole('onsite');
  Future<List<String>> _getAdminEmails() => _emailsByRole('admin');

  /// ADSB + TT + Admin — excludes on-site.
  Future<List<String>> _getSupportEmails() async {
    final results = await Future.wait([
      _getAdsbEmails(),
      _getTTEmails(),
      _getAdminEmails(),
    ]);
    return results.expand((e) => e).toList();
  }

  /// Every active user with this site in their site_ids.
  /// Includes the owner(s) and operator(s) of the site.
  Future<List<String>> _getSiteStakeholderEmails(String siteId) async {
    if (siteId.isEmpty) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('site_ids', arrayContains: siteId)
          .where('is_active', isEqualTo: true)
          .get();
      return snap.docs.map((d) => d['email'] as String).toList();
    } catch (e) {
      print('_getSiteStakeholderEmails error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // HIGH-LEVEL EVENTS
  // ═══════════════════════════════════════════════

  /// Ticket created. Notifies:
  /// - Reporter (confirmation)
  /// - All other site stakeholders (owner ↔ operator cross-notify)
  /// - All ADSB support
  Future<void> onTicketCreated(Ticket ticket) async {
    await addNotification(
      userId: ticket.createdBy,
      ticketId: ticket.id,
      title: 'Ticket Submitted',
      body: 'Your ticket ${ticket.id} has been received.',
      type: 'status_update',
    );

    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails.where((e) => e != ticket.createdBy).toList(),
      ticketId: ticket.id,
      title: 'New Issue Reported',
      body:
      '${ticket.createdByName} reported an issue at ${ticket.siteName}.',
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

  /// Escalated to TT.
  /// Notifies: site stakeholders + all TT advisors.
  Future<void> onEscalatedToTT(Ticket ticket) async {
    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'Issue Being Reviewed',
      body: '${ticket.id} is being reviewed by the ADSB team.',
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

  /// TT replied.
  /// Notifies: site stakeholders + ADSB + TT + Admin (not on-site).
  Future<void> onTTReplied(Ticket ticket) async {
    // Site stakeholders get an update — TT was consulted
    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'Issue Update',
      body: 'The ADSB team has an update on ${ticket.id}.',
      type: 'status_update',
    );

    final supportEmails = await _getSupportEmails();
    await _notifyMany(
      emails: supportEmails,
      ticketId: ticket.id,
      title: 'TT Advice Received',
      body: 'TT has replied on ${ticket.id}.',
      type: 'status_update',
    );
  }

  /// Sent to on-site.
  /// Notifies: site stakeholders + on-site team + ADSB + TT.
  Future<void> onSentToOnsite(Ticket ticket) async {
    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'On-Site Visit Scheduled',
      body: 'Our team will attend ${ticket.siteName} shortly.',
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

  /// Job claimed.
  /// Notifies: site stakeholders + ADSB.
  Future<void> onJobClaimed(Ticket ticket) async {
    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
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

  /// Job completed (on-site).
  /// Notifies: site stakeholders + ADSB + TT.
  Future<void> onJobCompleted(Ticket ticket) async {
    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'Issue Resolved',
      body: '${ticket.id} has been resolved. Please confirm.',
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

  /// Resolved remotely.
  /// Notifies: site stakeholders + TT.
  Future<void> onRemoteResolution(Ticket ticket) async {
    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'Ticket Resolved',
      body: '${ticket.id} was resolved remotely. Please confirm.',
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

  /// Client confirmed / closed.
  /// Notifies: site stakeholders + ADSB + TT + Admin.
  Future<void> onClientConfirmed(Ticket ticket) async {
    final supportEmails = await _getSupportEmails();
    await _notifyMany(
      emails: supportEmails,
      ticketId: ticket.id,
      title: 'Ticket Closed',
      body: '${ticket.id} has been confirmed and closed.',
      type: 'status_update',
    );

    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'Ticket Closed',
      body: '${ticket.id} is now closed.',
      type: 'status_update',
    );
  }

  /// Reopened.
  /// Notifies: site stakeholders + ADSB.
  Future<void> onTicketReopened(Ticket ticket) async {
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Ticket Reopened',
      body: '${ticket.id} was reopened. It is back in your queue.',
      type: 'status_update',
    );

    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'Ticket Reopened',
      body: 'Ticket ${ticket.id} has been reopened.',
      type: 'status_update',
    );
  }

  /// Cancelled.
  /// Notifies: site stakeholders + ADSB.
  Future<void> onTicketCancelled(Ticket ticket) async {
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Ticket Cancelled',
      body: '${ticket.id} was cancelled by the site team.',
      type: 'status_update',
    );

    final siteEmails = await _getSiteStakeholderEmails(ticket.siteId);
    await _notifyMany(
      emails: siteEmails,
      ticketId: ticket.id,
      title: 'Ticket Cancelled',
      body: 'Ticket ${ticket.id} has been cancelled.',
      type: 'status_update',
    );
  }
}