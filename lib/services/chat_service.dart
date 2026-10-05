import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

class ChatService {
  static const String _key = 'chat_messages';
  static const _uuid = Uuid();

  Future<List<ChatMessage>> getMessages(String ticketId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final all = raw
        .map((s) => ChatMessage.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    final filtered = all.where((m) => m.ticketId == ticketId).toList();
    filtered.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return filtered;
  }

  Future<void> sendMessage({
    required String ticketId,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;

    final msg = ChatMessage(
      id: _uuid.v4(),
      ticketId: ticketId,
      senderEmail: senderEmail,
      senderName: senderName,
      senderRole: senderRole,
      message: message.trim(),
      sentAt: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(msg.toJson()));
    await prefs.setStringList(_key, raw);
  }
}