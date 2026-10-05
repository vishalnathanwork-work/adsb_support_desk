import '../models/ticket_model.dart';
import 'api_client.dart';

class TicketService {
  // Create ticket — sends to MySQL
  Future<Ticket?> createTicket({
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
    final response = await ApiClient.post('tickets.php', {
      'action': 'create',
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_by_role': createdByRole,
      'site_location': siteLocation,
      'site_name': siteName,
      'product_type': productType,
      'product_issue': productIssue,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'description': description,
    });

    if (response['success'] == true) {
      return await getTicketById(response['ticket_id']);
    }
    return null;
  }

  // Get single ticket
  Future<Ticket?> getTicketById(String id) async {
    final response = await ApiClient.get('tickets.php', query: {
      'action': 'get',
      'id': id,
    });

    if (response['success'] == true && response['ticket'] != null) {
      return Ticket.fromJson(response['ticket']);
    }
    return null;
  }

  // Get my tickets
  Future<List<Ticket>> getMyTickets(String userEmail) async {
    final response = await ApiClient.get('tickets.php', query: {
      'action': 'mine',
      'email': userEmail,
    });

    if (response['success'] == true && response['tickets'] != null) {
      return (response['tickets'] as List)
          .map((j) => Ticket.fromJson(j))
          .toList();
    }
    return [];
  }

  // Get all tickets
  Future<List<Ticket>> getAllTickets() async {
    final response = await ApiClient.get('tickets.php', query: {
      'action': 'all',
    });

    if (response['success'] == true && response['tickets'] != null) {
      return (response['tickets'] as List)
          .map((j) => Ticket.fromJson(j))
          .toList();
    }
    return [];
  }

  // Get tickets by status (pending, verified, in_progress)
  Future<List<Ticket>> getTicketsByStatus(String status) async {
    final response = await ApiClient.get('tickets.php', query: {
      'action': 'status',
      'status': status,
    });

    if (response['success'] == true && response['tickets'] != null) {
      return (response['tickets'] as List)
          .map((j) => Ticket.fromJson(j))
          .toList();
    }
    return [];
  }

  // Convenience wrappers
  Future<List<Ticket>> getPendingTickets() => getTicketsByStatus('pending');
  Future<List<Ticket>> getVerifiedTickets() => getTicketsByStatus('verified');
  Future<List<Ticket>> getInProgressTickets() => getTicketsByStatus('in_progress');

  // Update ticket fields
  Future<bool> updateTicketFields(
      String ticketId,
      Map<String, dynamic> fields,
      ) async {
    final response = await ApiClient.post('tickets.php', {
      'action': 'update',
      'ticket_id': ticketId,
      'fields': fields,
    });
    return response['success'] == true;
  }

  // High-level status transitions
  Future<void> markVerified(String ticketId, String agentEmail, String agentName) async {
    await updateTicketFields(ticketId, {
      'status': 'verified',
      'assigned_to': agentEmail,
      'assigned_to_name': agentName,
    });
  }

  Future<void> resolveRemotely(String ticketId, String agentEmail, String agentName) async {
    await updateTicketFields(ticketId, {
      'status': 'closed',
      'assigned_to': agentEmail,
      'assigned_to_name': agentName,
      'resolved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> provideAdviceAndAssign({
    required String ticketId,
    required String advice,
    required String ttAgentEmail,
    required String ttAgentName,
  }) async {
    await updateTicketFields(ticketId, {
      'status': 'in_progress',
      'root_cause': advice,
      'solution_applied': 'Pending on-site work',
      'assigned_to': ttAgentEmail,
      'assigned_to_name': ttAgentName,
    });
  }

  Future<void> completeOnSite({
    required String ticketId,
    required String rootCause,
    required String solutionApplied,
    required String resolutionNotes,
    required String agentEmail,
    required String agentName,
  }) async {
    await updateTicketFields(ticketId, {
      'status': 'resolved',
      'root_cause': rootCause,
      'solution_applied': solutionApplied,
      'resolution_notes': resolutionNotes,
      'assigned_to': agentEmail,
      'assigned_to_name': agentName,
      'resolved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> confirmResolution(String id) async {
    await updateTicketFields(id, {'status': 'closed'});
  }

  Future<void> reopenTicket(String id) async {
    await updateTicketFields(id, {'status': 'reopened'});
  }

  Future<void> cancelTicket(String id) async {
    await updateTicketFields(id, {'status': 'cancelled'});
  }
}