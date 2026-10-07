import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';

class TicketService {
  final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('tickets');

  // ═══════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════

  Future<List<Ticket>> getAllTickets() async {
    try {
      final snapshot = await _col.get();
      final list = snapshot.docs
          .map((doc) => Ticket.fromJson({...doc.data(), 'ticket_id': doc.id}))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      print('getAllTickets error: $e');
      return [];
    }
  }

  Future<List<Ticket>> getMyTickets(String email) async {
    try {
      final snapshot =
      await _col.where('created_by', isEqualTo: email).get();
      final list = snapshot.docs
          .map((doc) => Ticket.fromJson({...doc.data(), 'ticket_id': doc.id}))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      print('getMyTickets error: $e');
      return [];
    }
  }

  Future<Ticket?> getTicketById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return Ticket.fromJson({...doc.data()!, 'ticket_id': doc.id});
    } catch (e) {
      print('getTicketById error: $e');
      return null;
    }
  }

  Future<List<Ticket>> getPendingTickets() => _byStatus('pending');
  Future<List<Ticket>> getVerifiedTickets() => _byStatus('verified');
  Future<List<Ticket>> getInProgressTickets() => _byStatus('in_progress');
  Future<List<Ticket>> getPendingOnsiteTickets() =>
      _byStatus('pending_onsite');

  Future<List<Ticket>> _byStatus(String status) async {
    try {
      final snapshot = await _col.where('status', isEqualTo: status).get();
      final list = snapshot.docs
          .map((doc) => Ticket.fromJson({...doc.data(), 'ticket_id': doc.id}))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    } catch (e) {
      print('_byStatus($status) error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // CREATE
  // ═══════════════════════════════════════════════

  Future<Ticket?> createTicket({
    required String createdBy,
    required String createdByName,
    required String createdByRole,
    required String siteId,
    required String siteName,
    required String siteLocation,
    required String laneId,
    required String laneName,
    required String laneDirection,
    required String productType,
    required String productIssue,
    required String contactName,
    required String contactPhone,
    required String description,
    required List<String> imageUrls,
  }) async {
    try {
      final now = DateTime.now();
      final datePart = '${now.year.toString().substring(2)}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final randPart =
      (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
      final ticketId = 'TKT-$datePart-$randPart';

      await _col.doc(ticketId).set({
        'ticket_id': ticketId,
        'created_by': createdBy,
        'created_by_name': createdByName,
        'created_by_role': createdByRole,
        'site_id': siteId,
        'site_name': siteName,
        'site_location': siteLocation,
        'lane_id': laneId,
        'lane_name': laneName,
        'lane_direction': laneDirection,
        'product_type': productType,
        'product_issue': productIssue,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'description': description,
        'status': 'pending',
        'assigned_to': null,
        'assigned_to_name': null,
        'root_cause': null,
        'solution_applied': null,
        'resolution_notes': null,
        'image_urls': imageUrls,
        'completion_image_url': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'resolved_at': null,
        'adsb_notified_at': FieldValue.serverTimestamp(),
        'call_started_at': null,
        'call_ended_at': null,
        'remote_fix_at': null,
        'verified_at': null,
        'tt_notified_at': null,
        'tt_solution_provided_at': null,
        'adsb_pickup_at': null,
        'dispatch_at': null,
        'arrived_at': null,
        'work_started_at': null,
        'work_completed_at': null,
        'evidence_uploaded_at': null,
        'client_confirmed_at': null,
        'reopened_at': null,
        'auto_closed_at': null,
        'no_show_at': null,
        'escalated_at': null,
      });

      await Future.delayed(const Duration(milliseconds: 500));
      return await getTicketById(ticketId);
    } catch (e) {
      print('createTicket error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // UPDATE
  // ═══════════════════════════════════════════════

  Future<bool> updateTicketFields(
      String ticketId,
      Map<String, dynamic> fields,
      ) async {
    try {
      await _col.doc(ticketId).update({
        ...fields,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('updateTicketFields error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // BUSINESS LOGIC
  // ═══════════════════════════════════════════════

  Future<void> assignToMe(
      String ticketId, String agentEmail, String agentName) async {
    await updateTicketFields(ticketId, {
      'assigned_to': agentEmail,
      'assigned_to_name': agentName,
    });
  }

  Future<void> markVerified(
      String ticketId, String agentEmail, String agentName) async {
    await updateTicketFields(ticketId, {
      'status': 'verified',
      'assigned_to': agentEmail,
      'assigned_to_name': agentName,
      'verified_at': FieldValue.serverTimestamp(),
      'escalated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logEscalated(String ticketId) async {
    await updateTicketFields(ticketId, {
      'escalated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveRemotely(
      String ticketId, String agentEmail, String agentName) async {
    await updateTicketFields(ticketId, {
      'status': 'resolved',
      'assigned_to': agentEmail,
      'assigned_to_name': agentName,
      'remote_fix_at': FieldValue.serverTimestamp(),
      'resolved_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> provideAdviceAndAssign({
    required String ticketId,
    required String advice,
    required String ttAgentEmail,
    required String ttAgentName,
  }) async {
    await updateTicketFields(ticketId, {
      'status': 'pending_onsite',
      'root_cause': advice,
      'solution_applied': 'Pending on-site work',
      'assigned_to': ttAgentEmail,
      'assigned_to_name': ttAgentName,
      'tt_solution_provided_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> claimOnsiteJob({
    required String ticketId,
    required String adsbEmail,
    required String adsbName,
  }) async {
    await updateTicketFields(ticketId, {
      'status': 'in_progress',
      'assigned_to': adsbEmail,
      'assigned_to_name': adsbName,
      'adsb_pickup_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeOnSite({
    required String ticketId,
    required String rootCause,
    required String solutionApplied,
    required String resolutionNotes,
    required String agentEmail,
    required String agentName,
    String? completionImageUrl,
  }) async {
    final Map<String, dynamic> fields = {
      'status': 'resolved',
      'root_cause': rootCause,
      'solution_applied': solutionApplied,
      'resolution_notes': resolutionNotes,
      'assigned_to': agentEmail,
      'assigned_to_name': agentName,
      'work_completed_at': FieldValue.serverTimestamp(),
      'resolved_at': FieldValue.serverTimestamp(),
    };

    if (completionImageUrl != null &&
        completionImageUrl.trim().isNotEmpty) {
      fields['completion_image_url'] = completionImageUrl;
      fields['evidence_uploaded_at'] = FieldValue.serverTimestamp();
    }

    await updateTicketFields(ticketId, fields);
  }

  Future<void> confirmResolution(String ticketId) async {
    await updateTicketFields(ticketId, {
      'status': 'closed',
      'client_confirmed_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reopenTicket(String ticketId) async {
    await updateTicketFields(ticketId, {
      'status': 'pending',
      'reopened_at': FieldValue.serverTimestamp(),
      'assigned_to': null,
      'assigned_to_name': null,
    });
  }

  Future<void> cancelTicket(String ticketId) async {
    await updateTicketFields(ticketId, {'status': 'cancelled'});
  }
}