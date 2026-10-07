import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';
import '../utils/date_formatter.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _systemCard();
    return _userBubble();
  }

  // ─────────────────────────────────────────
  // SYSTEM SUMMARY CARD
  // ─────────────────────────────────────────

  Widget _systemCard() {
    final isInternal = message.channel == 'internal';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isInternal
              ? const Color(0xFF5E35B1).withOpacity(0.06)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInternal
                ? const Color(0xFF5E35B1).withOpacity(0.3)
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInternal ? Icons.lock_outline : Icons.info_outline,
                  size: 16,
                  color: isInternal
                      ? const Color(0xFF5E35B1)
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isInternal ? 'Internal Ticket Details' : 'Ticket Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isInternal
                        ? const Color(0xFF5E35B1)
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormatter.relative(message.sentAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              message.message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // USER MESSAGE
  // ─────────────────────────────────────────

  Widget _userBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(
                message.senderName.isEmpty
                    ? '?'
                    : message.senderName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) _senderHeader(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe
                        ? null
                        : Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    DateFormatter.relative(message.sentAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _senderHeader() {
    final roleBadge = _roleBadge();
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.senderName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (roleBadge != null) ...[
            const SizedBox(width: 4),
            roleBadge,
          ],
        ],
      ),
    );
  }

  Widget? _roleBadge() {
    Color color;
    String label;

    switch (message.senderRole) {
      case 'adsb':
        color = AppColors.primary;
        label = 'ADSB';
        break;
      case 'technician':
        color = const Color(0xFF5E35B1);
        label = 'TT';
        break;
      case 'admin':
        color = AppColors.textPrimary;
        label = 'ADMIN';
        break;
      case 'client':
      case 'operator':
        return null; // no badge for external users
      default:
        return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}