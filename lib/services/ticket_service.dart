import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket_model.dart';

class TicketService {
  static const String _key = 'app_tickets';
  static int _idCounter = 1002;

  static final List<Ticket> _initialMockTickets = [
    Ticket(
      id: 'TICK-1001',
      createdBy: 'client@adsb.com',
      createdByName: 'Parken Client',
      createdByRole: 'client',
      siteLocation: 'Melaka, Malaysia',
      siteName: 'Parken HQ',
      productType: 'Parken Barrier',
      productIssue: 'Barrier stuck',
      contactName: 'Parken Client',
      contactPhone: '+60 12-345 6789',
      description: 'The entrance barrier is stuck half open.',
      imagePaths: [],
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  Future<List<Ticket>> getAllTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    if (raw == null) {
      await _saveTickets(_initialMockTickets);
      return List.from(_initialMockTickets);
    }

    return raw
        .map((s) => Ticket.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveTickets(List<Ticket> tickets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = tickets.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }

  Future<List<Ticket>> getMyTickets(String email) async {
    final all = await getAllTickets();
    final list = all.where((t) => t.createdBy == email).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Ticket?> getTicketById(String id) async {
    final all = await getAllTickets();
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Ticket> createTicket({
    required String createdBy,
    required String createdByName,
    required String createdByRole,
    required String siteLocation,
    required String siteName,
    required String productType,
    required String productIssue,
    required String contactName,
    required String contactPhone,
    required String description,
    required List<String> imagePaths,
  }) async {
    final all = await getAllTickets();
    final ticketId = 'TICK-${_idCounter++}';
    final now = DateTime.now();

    final newTicket = Ticket(
      id: ticketId,
      createdBy: createdBy,
      createdByName: createdByName,
      createdByRole: createdByRole,
      siteLocation: siteLocation,
      siteName: siteName,
      productType: productType,
      productIssue: productIssue,
      contactName: contactName,
      contactPhone: contactPhone,
      description: description,
      imagePaths: imagePaths,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    all.insert(0, newTicket);
    await _saveTickets(all);
    return newTicket;
  }

  Future<void> confirmResolution(String ticketId) async {
    await _updateFields(ticketId, {
      'status': 'closed',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> reopenTicket(String ticketId) async {
    await _updateFields(ticketId, {
      'status': 'reopened',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> cancelTicket(String ticketId) async {
    await _updateFields(ticketId, {
      'status': 'cancelled',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ADSB team picks up a ticket
  Future<void> assignToMe(String ticketId, String agentEmail, String agentName) async {
    await _updateFields(ticketId, {
      'assignedTo': agentEmail,
      'assignedToName': agentName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Mark as verified (escalate to TT)
  Future<void> markVerified(String ticketId, String agentEmail, String agentName) async {
    await _updateFields(ticketId, {
      'status': 'verified',
      'assignedTo': agentEmail,
      'assignedToName': agentName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Resolve remotely (close without on-site visit)
  Future<void> resolveRemotely(String ticketId, String agentEmail, String agentName) async {
    await _updateFields(ticketId, {
      'status': 'closed',
      'assignedTo': agentEmail,
      'assignedToName': agentName,
      'resolvedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // All pending tickets (for ADSB queue)
  Future<List<Ticket>> getPendingTickets() async {
    final all = await getAllTickets();
    final pending = all.where((t) => t.status == 'pending').toList();
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  // All verified tickets (for TT queue)
  Future<List<Ticket>> getVerifiedTickets() async {
    final all = await getAllTickets();
    final verified = all.where((t) => t.status == 'verified').toList();
    verified.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return verified;
  }

  // All in-progress tickets (for on-site queue)
  Future<List<Ticket>> getInProgressTickets() async {
    final all = await getAllTickets();
    final inProg = all.where((t) => t.status == 'in_progress').toList();
    inProg.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return inProg;
  }

  // TT Team - provide advice and assign to on-site
  Future<void> provideAdviceAndAssign({
    required String ticketId,
    required String advice,
    required String ttAgentEmail,
    required String ttAgentName,
  }) async {
    await _updateFields(ticketId, {
      'status': 'in_progress',
      'rootCause': advice,
      'solutionApplied': 'Pending on-site work',
      'assignedTo': ttAgentEmail,
      'assignedToName': ttAgentName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // On-site resolution (final)
  Future<void> completeOnSite({
    required String ticketId,
    required String rootCause,
    required String solutionApplied,
    required String resolutionNotes,
    required String agentEmail,
    required String agentName,
  }) async {
    await _updateFields(ticketId, {
      'status': 'resolved',
      'rootCause': rootCause,
      'solutionApplied': solutionApplied,
      'resolutionNotes': resolutionNotes,
      'assignedTo': agentEmail,
      'assignedToName': agentName,
      'resolvedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Internal helper for updating fields
  Future<void> _updateFields(String ticketId, Map<String, dynamic> fields) async {
    final all = await getAllTickets();
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == ticketId) {
        final map = all[i].toJson();
        map.addAll(fields);
        all[i] = Ticket.fromJson(map);
        break;
      }
    }
    await _saveTickets(all);
  }
}
