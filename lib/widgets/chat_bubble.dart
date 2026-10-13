import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';
import '../utils/date_formatter.dart';
import 'chat_attachment_view.dart';

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
  // SYSTEM CARD
  // ─────────────────────────────────────────

  Widget _systemCard() {
    final hasAttachments = message.imageUrls.isNotEmpty ||
        message.attachmentUrls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Ticket Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
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
            if (message.message.isNotEmpty)
              SelectableText(
                message.message,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            if (hasAttachments) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Attached Files',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ChatAttachmentView(
                      imageUrls: message.imageUrls,
                      attachmentUrls: message.attachmentUrls,
                      attachmentNames: message.attachmentNames,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // USER MESSAGE
  // ─────────────────────────────────────────

  Widget _userBubble() {
    final isInternalSide = message.isInternalSender;
    final sideColor =
    isInternalSide ? AppColors.primary : AppColors.accent;

    final hasAttachments = message.imageUrls.isNotEmpty ||
        message.attachmentUrls.isNotEmpty;

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
              backgroundColor: sideColor.withOpacity(0.15),
              child: Text(
                message.senderName.isEmpty
                    ? '?'
                    : message.senderName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: sideColor,
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
                if (!isMe) _senderHeader(sideColor),
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
                    border:
                    isMe ? null : Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.message.isNotEmpty)
                        Text(
                          message.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      if (hasAttachments) ...[
                        if (message.message.isNotEmpty)
                          const SizedBox(height: 8),
                        ChatAttachmentView(
                          imageUrls: message.imageUrls,
                          attachmentUrls: message.attachmentUrls,
                          attachmentNames: message.attachmentNames,
                        ),
                      ],
                    ],
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

  Widget _senderHeader(Color sideColor) {
    if (message.isInternalSender) {
      return const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 3),
        child: Text(
          'ADSB Support',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
    }

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
          const SizedBox(width: 4),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: sideColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              message.displayRole,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: sideColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}