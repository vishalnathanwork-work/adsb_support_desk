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

  /// Send to one specific user (skips empty).
  Future<void> _notifyUser({
    required String email,
    required String ticketId,
    required String title,
    required String body,
    required String type,
  }) async {
    if (email.isEmpty) return;
    await addNotification(
      userId: email,
      ticketId: ticketId,
      title: title,
      body: body,
      type: type,
    );
  }

  /// Notify the ticket reporter.
  Future<void> _notifyReporter(Ticket ticket, {
    required String title,
    required String body,
    required String type,
  }) async {
    await _notifyUser(
      email: ticket.createdBy,
      ticketId: ticket.id,
      title: title,
      body: body,
      type: type,
    );
  }

  /// Notify the specific assignee (if set).
  Future<void> _notifyAssignee(Ticket ticket, {
    required String title,
    required String body,
    required String type,
  }) async {
    final email = ticket.assignedTo ?? '';
    if (email.isEmpty) return;
    await _notifyUser(
      email: email,
      ticketId: ticket.id,
      title: title,
      body: body,
      type: type,
    );
  }

  /// ✅ Cross-notify: owner + operator on the same site
  /// Returns other stakeholder emails on the site (excludes reporter).
  Future<List<String>> _getOtherSiteStakeholders(Ticket ticket) async {
    if (ticket.siteId.isEmpty) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('site_ids', arrayContains: ticket.siteId)
          .where('is_active', isEqualTo: true)
          .get();

      return snap.docs
          .map((d) => d['email'] as String)
          .where((e) =>
      e.isNotEmpty &&
          e != ticket.createdBy &&
          e != ticket.assignedTo)
          .toList();
    } catch (e) {
      print('_getOtherSiteStakeholders error: $e');
      return [];
    }
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

  Future<List<String>> _getAdminEmails() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      return snap.docs
          .map((d) => (d.data()['email'] ?? '') as String)
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      print('_getAdminEmails error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // USER REGISTRATION EVENTS
  // ═══════════════════════════════════════════════

  Future<void> onNewUserRegistered({
    required String userName,
    required String userEmail,
    required String userRole,
    required List<String> siteIds,
  }) async {
    final adminEmails = await _getAdminEmails();
    if (adminEmails.isEmpty) return;

    final roleLabel = userRole == 'owner' ? 'Site Owner' : 'Site Operator';
    final siteText = siteIds.length == 1
        ? '1 site'
        : '${siteIds.length} sites';

    await _notifyMany(
      emails: adminEmails,
      ticketId: '',
      title: 'New Registration Request',
      body: '$userName ($roleLabel) has registered for $siteText '
          'and is waiting for approval.',
      type: 'user_registration',
    );
  }

  Future<void> onUserApproved({
    required String userEmail,
    required String userName,
  }) async {
    await addNotification(
      userId: userEmail,
      ticketId: '',
      title: 'Account Approved',
      body: 'Welcome, $userName! Your account has been approved. '
          'You can now log in and use the app.',
      type: 'user_approved',
    );
  }

  Future<void> onUserRejected({
    required String userEmail,
    required String userName,
  }) async {
    await addNotification(
      userId: userEmail,
      ticketId: '',
      title: 'Registration Declined',
      body: 'Hi $userName, your registration request was not approved. '
          'Contact ADSB support for assistance.',
      type: 'user_rejected',
    );
  }

  // ═══════════════════════════════════════════════
  // TICKET LIFECYCLE
  // ═══════════════════════════════════════════════

  /// Ticket created.
  /// Notifies:
  /// - Reporter (confirmation)
  /// - Other site stakeholders (owner ↔ operator cross-notify) ✅
  /// - All ADSB agents (new ticket to verify)
  Future<void> onTicketCreated(Ticket ticket) async {
    // 1. Reporter
    await _notifyReporter(
      ticket,
      title: 'Ticket Submitted',
      body: 'Your ticket ${ticket.id} has been received.',
      type: 'status_update',
    );

    // 2. Other stakeholders on same site (NEW)
    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'New Issue on Your Site',
      body: '${ticket.createdByName} reported an issue at '
          '${ticket.siteName}: ${ticket.productIssue}',
      type: 'status_update',
    );

    // 3. All ADSB
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'New Ticket',
      body: '${ticket.createdByName} created ${ticket.id} — '
          '${ticket.productIssue}',
      type: 'status_update',
    );
  }

  /// Escalated to TT.
  /// Notifies:
  /// - Reporter (status update)
  /// - Other site stakeholders (NEW)
  /// - The assigned TT (if set) OR all TT (if unassigned)
  Future<void> onEscalatedToTT(Ticket ticket) async {
    // 1. Reporter
    await _notifyReporter(
      ticket,
      title: 'Issue Being Reviewed',
      body: '${ticket.id} is being reviewed by the ADSB team.',
      type: 'status_update',
    );

    // 2. Other site stakeholders (NEW)
    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'Issue Update',
      body: '${ticket.id} on your site is being reviewed by ADSB.',
      type: 'status_update',
    );

    // 3. Assigned TT or all TT
    if (ticket.assignedTo != null && ticket.assignedTo!.isNotEmpty) {
      await _notifyAssignee(
        ticket,
        title: 'New Review Assigned',
        body: '${ticket.id} has been escalated to you for review.',
        type: 'assignment',
      );
    } else {
      final ttEmails = await _getTTEmails();
      await _notifyMany(
        emails: ttEmails,
        ticketId: ticket.id,
        title: 'New Ticket Escalated',
        body: '${ticket.id} needs a technical advisor review.',
        type: 'status_update',
      );
    }
  }

  /// TT replied with advice.
  /// Notifies:
  /// - The assigned ADSB agent (acts on it)
  /// - Other site stakeholders (awareness) — optional, keep off
  Future<void> onTTReplied(Ticket ticket) async {
    await _notifyAssignee(
      ticket,
      title: 'Advice Received',
      body: 'Technical Team has replied on ${ticket.id}.',
      type: 'status_update',
    );
  }

  /// Sent to on-site.
  /// Notifies:
  /// - Reporter (awareness)
  /// - Other site stakeholders (cross-notify)
  /// - All on-site agents (unclaimed job)
  Future<void> onSentToOnsite(Ticket ticket) async {
    // 1. Reporter
    await _notifyReporter(
      ticket,
      title: 'On-Site Visit Scheduled',
      body: 'Our team will attend ${ticket.siteName} shortly.',
      type: 'schedule',
    );

    // 2. Other site stakeholders
    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'On-Site Visit Scheduled',
      body: 'ADSB scheduled on-site work for ${ticket.id} at '
          '${ticket.siteName}.',
      type: 'schedule',
    );

    // 3. All on-site
    final onsiteEmails = await _getOnsiteEmails();
    await _notifyMany(
      emails: onsiteEmails,
      ticketId: ticket.id,
      title: 'New On-Site Job',
      body: '${ticket.id} — ${ticket.siteName}. Claim it from Jobs.',
      type: 'schedule',
    );
  }

  /// Job claimed.
  /// Notifies:
  /// - Reporter (technician on the way)
  /// - Other site stakeholders
  /// - All ADSB
  Future<void> onJobClaimed(Ticket ticket) async {
    // 1. Reporter
    await _notifyReporter(
      ticket,
      title: 'Technician On The Way',
      body: 'A technician has been assigned to ${ticket.id}.',
      type: 'schedule',
    );

    // 2. Other site stakeholders
    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'Technician On The Way',
      body: 'A technician has been assigned to ${ticket.id} '
          'at ${ticket.siteName}.',
      type: 'schedule',
    );

    // 3. All ADSB
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Job Claimed',
      body: '${ticket.assignedToName ?? "A technician"} claimed '
          '${ticket.id}.',
      type: 'status_update',
    );
  }

  /// Job completed by on-site.
  /// Notifies:
  /// - Reporter (please confirm)
  /// - Other site stakeholders
  /// - All ADSB
  Future<void> onJobCompleted(Ticket ticket) async {
    // 1. Reporter
    await _notifyReporter(
      ticket,
      title: 'Issue Resolved',
      body: '${ticket.id} has been resolved. Please confirm.',
      type: 'resolved',
    );

    // 2. Other site stakeholders
    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'Issue Resolved',
      body: '${ticket.id} at ${ticket.siteName} has been resolved.',
      type: 'resolved',
    );

    // 3. All ADSB
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'On-Site Work Completed',
      body: '${ticket.id} was resolved by on-site team.',
      type: 'status_update',
    );
  }

  /// Resolved remotely by ADSB.
  /// Notifies:
  /// - Reporter (please confirm)
  /// - Other site stakeholders
  Future<void> onRemoteResolution(Ticket ticket) async {
    await _notifyReporter(
      ticket,
      title: 'Ticket Resolved',
      body: '${ticket.id} was resolved remotely. Please confirm.',
      type: 'resolved',
    );

    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'Ticket Resolved',
      body: '${ticket.id} at ${ticket.siteName} was resolved remotely.',
      type: 'resolved',
    );
  }

  /// Client confirmed / closed.
  /// Notifies:
  /// - All ADSB (awareness)
  /// - TT advisor (if they were involved)
  /// - Other site stakeholders
  Future<void> onClientConfirmed(Ticket ticket) async {
    // 1. All ADSB
    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Ticket Closed',
      body: '${ticket.id} has been confirmed and closed.',
      type: 'status_update',
    );

    // 2. TT advisor if involved
    if (ticket.ttAdvisorEmail != null &&
        ticket.ttAdvisorEmail!.isNotEmpty) {
      await _notifyUser(
        email: ticket.ttAdvisorEmail!,
        ticketId: ticket.id,
        title: 'Ticket Closed',
        body: '${ticket.id} (you advised) has been confirmed and closed.',
        type: 'status_update',
      );
    }

    // 3. Other site stakeholders
    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'Ticket Closed',
      body: '${ticket.id} at ${ticket.siteName} is now closed.',
      type: 'status_update',
    );
  }

  /// Reopened.
  /// Notifies:
  /// - Reporter (confirmation)
  /// - Other site stakeholders
  /// - All ADSB
  Future<void> onTicketReopened(Ticket ticket) async {
    await _notifyReporter(
      ticket,
      title: 'Ticket Reopened',
      body: '${ticket.id} has been reopened.',
      type: 'status_update',
    );

    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'Ticket Reopened',
      body: '${ticket.id} at ${ticket.siteName} has been reopened.',
      type: 'status_update',
    );

    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Ticket Reopened',
      body: '${ticket.id} was reopened and needs attention.',
      type: 'status_update',
    );
  }

  /// Cancelled.
  /// Notifies:
  /// - Reporter (confirmation)
  /// - Other site stakeholders
  /// - All ADSB
  Future<void> onTicketCancelled(Ticket ticket) async {
    await _notifyReporter(
      ticket,
      title: 'Ticket Cancelled',
      body: '${ticket.id} has been cancelled.',
      type: 'status_update',
    );

    final otherStakeholders = await _getOtherSiteStakeholders(ticket);
    await _notifyMany(
      emails: otherStakeholders,
      ticketId: ticket.id,
      title: 'Ticket Cancelled',
      body: '${ticket.id} at ${ticket.siteName} was cancelled.',
      type: 'status_update',
    );

    final adsbEmails = await _getAdsbEmails();
    await _notifyMany(
      emails: adsbEmails,
      ticketId: ticket.id,
      title: 'Ticket Cancelled',
      body: '${ticket.id} was cancelled by the site team.',
      type: 'status_update',
    );
  }

  // ═══════════════════════════════════════════════
  // CHAT MESSAGES (targeted + cross-notify)
  // ═══════════════════════════════════════════════

  /// Chat message on a ticket.
  ///
  /// Routing:
  /// - Sender = reporter → notify assignee (or all ADSB if unassigned)
  ///   + other site stakeholders
  /// - Sender = internal → notify reporter + assignee (if different)
  ///   + other site stakeholders
  Future<void> onChatMessage({
    required String ticketId,
    required String ticketSiteId,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    required String messagePreview,
    required String ticketCreatedBy,
    required String? assigneeEmail,
  }) async {
    final recipients = <String>{};

    final isSenderReporter = senderEmail == ticketCreatedBy;
    final isSenderInternal =
        senderRole != 'owner' && senderRole != 'operator';

    if (isSenderReporter) {
      // Reporter sent → notify assignee (or all ADSB if unassigned)
      if (assigneeEmail != null && assigneeEmail.isNotEmpty) {
        recipients.add(assigneeEmail);
      } else {
        final adsbEmails = await _getAdsbEmails();
        recipients.addAll(adsbEmails);
      }

      // Also notify other site stakeholders
      if (ticketSiteId.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('site_ids', arrayContains: ticketSiteId)
              .where('is_active', isEqualTo: true)
              .get();
          recipients.addAll(snap.docs
              .map((d) => d['email'] as String)
              .where((e) =>
          e.isNotEmpty &&
              e != senderEmail &&
              e != assigneeEmail));
        } catch (e) {
          print('site stakeholders error: $e');
        }
      }
    } else if (isSenderInternal) {
      // Internal sent → notify reporter + assignee + other stakeholders
      if (ticketCreatedBy.isNotEmpty) {
        recipients.add(ticketCreatedBy);
      }
      if (assigneeEmail != null &&
          assigneeEmail.isNotEmpty &&
          assigneeEmail != senderEmail) {
        recipients.add(assigneeEmail);
      }

      // Other site stakeholders
      if (ticketSiteId.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('site_ids', arrayContains: ticketSiteId)
              .where('is_active', isEqualTo: true)
              .get();
          recipients.addAll(snap.docs
              .map((d) => d['email'] as String)
              .where((e) =>
          e.isNotEmpty &&
              e != senderEmail &&
              e != ticketCreatedBy &&
              e != assigneeEmail));
        } catch (e) {
          print('site stakeholders error: $e');
        }
      }
    }

    // Remove sender
    recipients.remove(senderEmail);

    if (recipients.isEmpty) return;

    final preview = messagePreview.length > 60
        ? '${messagePreview.substring(0, 60)}...'
        : messagePreview;

    final roleLabel = _chatLabel(senderRole);
    final body = messagePreview.isEmpty
        ? '$senderName ($roleLabel) sent an attachment'
        : '$senderName ($roleLabel): $preview';

    await _notifyMany(
      emails: recipients.toList(),
      ticketId: ticketId,
      title: 'New message on $ticketId',
      body: body,
      type: 'chat_message',
    );
  }

  String _chatLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Site Owner';
      case 'operator':
        return 'Site Operator';
      case 'adsb':
      case 'technician':
      case 'onsite':
      case 'admin':
        return 'ADSB Support';
      default:
        return 'User';
    }
  }
}