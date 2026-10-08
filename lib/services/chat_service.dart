import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/ticket_model.dart';

class ChatService {
  final _col = FirebaseFirestore.instance.collection('chat_messages');

  // ═══════════════════════════════════════════════
  // STREAM — filtered by ticket + channel
  // ═══════════════════════════════════════════════

  Stream<List<ChatMessage>> streamMessages({
    required String ticketId,
    required String channel,
  }) {
    return _col
        .where('ticket_id', isEqualTo: ticketId)
        .where('channel', isEqualTo: channel)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ChatMessage.fromJson({
        ...doc.data(),
        'id': doc.id,
      }))
          .toList();
      list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return list;
    });
  }

  // ═══════════════════════════════════════════════
  // SEND
  // ═══════════════════════════════════════════════

  Future<void> sendMessage({
    required String ticketId,
    required String channel,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;

    try {
      await _col.add({
        'ticket_id': ticketId,
        'channel': channel,
        'sender_email': senderEmail,
        'sender_name': senderName,
        'sender_role': senderRole,
        'message': message.trim(),
        'is_system': false,
        'sent_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('sendMessage error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // AUTO-POST TICKET SUMMARY (once per channel)
  // ═══════════════════════════════════════════════

  Future<void> ensureTicketSummary({
    required Ticket ticket,
    required String channel,
  }) async {
    try {
      final existing = await _col
          .where('ticket_id', isEqualTo: ticket.id)
          .where('channel', isEqualTo: channel)
          .where('is_system', isEqualTo: true)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return;

      final summary = _buildSummary(ticket, channel);

      await _col.add({
        'ticket_id': ticket.id,
        'channel': channel,
        'sender_email': 'system',
        'sender_name': 'System',
        'sender_role': 'system',
        'message': summary,
        'is_system': true,
        'sent_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('ensureTicketSummary error: $e');
    }
  }

  String _buildSummary(Ticket t, String channel) {
    final buffer = StringBuffer();
    buffer.writeln('📋 TICKET SUMMARY');
    buffer.writeln('─────────────────────');
    buffer.writeln('Ticket ID: ${t.id}');
    buffer.writeln('Site: ${t.siteName}');
    buffer.writeln('Location: ${t.siteLocation}');
    buffer.writeln(
        'Parking: ${t.laneName} (${t.laneDirectionDisplay})');
    buffer.writeln('Product: ${t.productType}');
    buffer.writeln('Issue: ${t.productIssue}');
    buffer.writeln(
        'Reported by: ${t.createdByName} (${t.createdByRole})');
    buffer.writeln(
        'Contact: ${t.contactName} — ${t.contactPhone}');
    if (t.description.isNotEmpty) {
      buffer.writeln('Description: ${t.description}');
    }
    buffer.writeln('Status: ${t.statusDisplay}');

    if (channel == 'internal') {
      buffer.writeln('');
      buffer.writeln('🔒 INTERNAL CHANNEL');
      buffer.writeln(
          'ADSB ↔ TT coordination only. Client cannot see this.');
    } else {
      buffer.writeln('');
      buffer.writeln('💬 TICKET CHANNEL');
      buffer.writeln('Client ↔ ADSB discussion.');
    }

    return buffer.toString().trim();
  }
}