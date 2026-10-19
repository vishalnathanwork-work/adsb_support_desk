import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/ticket_model.dart';
import 'notification_service.dart';

class ChatService {
  final _col = FirebaseFirestore.instance.collection('chat_messages');

  static const String channelId = 'ticket';

  // ═══════════════════════════════════════════════
  // STREAM
  // ═══════════════════════════════════════════════

  Stream<List<ChatMessage>> streamMessages({
    required String ticketId,
  }) {
    return _col
        .where('ticket_id', isEqualTo: ticketId)
        .where('channel', isEqualTo: channelId)
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
  // SEND — user message with optional attachments
  // ═══════════════════════════════════════════════

  Future<void> sendMessage({
    required String ticketId,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    required String message,
    List<String> imageUrls = const [],
    List<String> attachmentUrls = const [],
    List<String> attachmentNames = const [],
  }) async {
    if (message.trim().isEmpty &&
        imageUrls.isEmpty &&
        attachmentUrls.isEmpty) {
      return;
    }

    try {
      await _col.add({
        'ticket_id': ticketId,
        'channel': channelId,
        'sender_email': senderEmail,
        'sender_name': senderName,
        'sender_role': senderRole,
        'message': message.trim(),
        'is_system': false,
        'image_urls': imageUrls,
        'attachment_urls': attachmentUrls,
        'attachment_names': attachmentNames,
        'sent_at': FieldValue.serverTimestamp(),
      });

      //NEW: Notify stakeholders
      try {
        final ticket = await FirebaseFirestore.instance
            .collection('tickets')
            .doc(ticketId)
            .get();

        if (ticket.exists) {
          final data = ticket.data()!;
          await NotificationService().onChatMessage(
            ticketId: ticketId,
            ticketSiteId: data['site_id'] ?? '',
            senderEmail: senderEmail,
            senderName: senderName,
            senderRole: senderRole,
            messagePreview: message.trim(),
            ticketCreatedBy: data['created_by'] ?? '',
            assigneeEmail: data['assigned_to'] as String?,
          );
        }
      } catch (e) {
        print('onChatMessage notification failed: $e');
      }
    } catch (e) {
      print('sendMessage error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // SEND — system message
  // ═══════════════════════════════════════════════

  Future<void> sendSystemMessage({
    required String ticketId,
    required String message,
    List<String> imageUrls = const [],
  }) async {
    try {
      await _col.add({
        'ticket_id': ticketId,
        'channel': channelId,
        'sender_email': 'system',
        'sender_name': 'System',
        'sender_role': 'system',
        'message': message,
        'is_system': true,
        'image_urls': imageUrls,
        'attachment_urls': const [],
        'attachment_names': const [],
        'sent_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('sendSystemMessage error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // AUTO-POST TICKET SUMMARY
  // ═══════════════════════════════════════════════

  Future<void> ensureTicketSummary(Ticket ticket) async {
    try {
      final existing = await _col
          .where('ticket_id', isEqualTo: ticket.id)
          .where('channel', isEqualTo: channelId)
          .where('is_system', isEqualTo: true)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await refreshSummaryImages(ticket);
        return;
      }

      final summary = _buildSummary(ticket);
      final images = _collectImages(ticket);

      await _col.add({
        'ticket_id': ticket.id,
        'channel': channelId,
        'sender_email': 'system',
        'sender_name': 'System',
        'sender_role': 'system',
        'message': summary,
        'is_system': true,
        'image_urls': images,
        'attachment_urls': const [],
        'attachment_names': const [],
        'sent_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('ensureTicketSummary error: $e');
    }
  }

  Future<void> refreshSummaryImages(Ticket ticket) async {
    try {
      final snap = await _col
          .where('ticket_id', isEqualTo: ticket.id)
          .where('channel', isEqualTo: channelId)
          .where('is_system', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      final images = _collectImages(ticket);

      await snap.docs.first.reference.update({
        'image_urls': images,
      });
    } catch (e) {
      print('refreshSummaryImages error: $e');
    }
  }

  List<String> _collectImages(Ticket t) {
    final images = <String>{
      ...t.imageUrls,
      if (t.completionImageUrl != null &&
          t.completionImageUrl!.isNotEmpty)
        t.completionImageUrl!,
    };
    return images.toList();
  }

  String _buildSummary(Ticket t) {
    final buffer = StringBuffer();
    buffer.writeln('📋 TICKET SUMMARY');
    buffer.writeln('─────────────────────');
    buffer.writeln('Ticket ID: ${t.id}');
    buffer.writeln('Site: ${t.siteName}');
    buffer.writeln('Location: ${t.siteLocation}');

    // Lanes grouped by zone
    if (t.lanes.isNotEmpty) {
      buffer.writeln('Affected points:');
      final byZone = t.lanesByZone;
      byZone.forEach((zoneName, lanes) {
        buffer.write('  📍 $zoneName: ');
        buffer.write(lanes.map((l) => l['name'] ?? '').join(', '));
        buffer.writeln();
      });
    }

    buffer.writeln('Product: ${t.productType}');
    buffer.writeln('Issue: ${t.productIssue}');
    buffer.writeln('Reported by: ${t.createdByName}');
    buffer.writeln('Contact: ${t.contactName} — ${t.contactPhone}');
    if (t.description.isNotEmpty) {
      buffer.writeln('Description: ${t.description}');
    }
    buffer.writeln('Status: ${t.statusDisplay}');

    final imageCount = _collectImages(t).length;
    if (imageCount > 0) {
      buffer.writeln('Photos attached: $imageCount');
    }

    return buffer.toString().trim();
  }
}