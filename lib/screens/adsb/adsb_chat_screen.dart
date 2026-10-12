import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/chat_bubble.dart';

/// Unified ticket chat — used by EVERYONE.
/// Site Owner, Site Operator, ADSB Support, TT, On-Site, Admin.
/// TT/On-Site/ADSB all appear as "ADSB Team" to external users.
class AdsbChatScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;

  const AdsbChatScreen({
    super.key,
    required this.ticketId,
    required this.user,
  });

  @override
  State<AdsbChatScreen> createState() => _AdsbChatScreenState();
}

class _AdsbChatScreenState extends State<AdsbChatScreen> {
  final _chatService = ChatService();
  final _ticketService = TicketService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Ticket? _ticket;
  bool _summaryReady = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final t = await _ticketService.getTicketById(widget.ticketId);
    if (!mounted) return;
    setState(() => _ticket = t);

    if (t != null) {
      await _chatService.ensureTicketSummary(t);
      if (!mounted) return;
      setState(() => _summaryReady = true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Chat is open while the ticket is active.
  /// Read-only once the ticket is closed or cancelled.
  bool get _chatOpen {
    if (_ticket == null) return false;
    return _ticket!.status != 'closed' && _ticket!.status != 'cancelled';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    if (!_chatOpen) return;

    setState(() => _isSending = true);

    // Auto-escalate: if ADSB replies first on a pending ticket,
    // the ticket moves to "verified" so TT/on-site know to review.
    final isAdsb = widget.user.role == 'adsb';
    if (isAdsb && _ticket != null && _ticket!.status == 'pending') {
      await _ticketService.autoEscalateIfNeeded(
        ticketId: widget.ticketId,
        reason: text,
        adsbEmail: widget.user.email,
        adsbName: widget.user.name,
      );

      final fresh = await _ticketService.getTicketById(widget.ticketId);
      if (mounted) setState(() => _ticket = fresh);
    }

    _controller.clear();

    await _chatService.sendMessage(
      ticketId: widget.ticketId,
      senderEmail: widget.user.email,
      senderName: widget.user.name,
      senderRole: widget.user.role,
      message: text,
    );

    if (!mounted) return;
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat — ${widget.ticketId}',
              style: const TextStyle(fontSize: 16),
            ),
            if (_ticket != null)
              Text(
                '${_ticket!.siteName} · ${_ticket!.laneName}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Closed banner ───
          if (!_chatOpen && _ticket != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppColors.textSecondary.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This ticket is closed. Chat is read-only.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Messages ───
          Expanded(
            child: !_summaryReady
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<ChatMessage>>(
              stream: _chatService.streamMessages(
                ticketId: widget.ticketId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say something.'),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMe = m.senderEmail == widget.user.email;
                    return ChatBubble(message: m, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // ─── Input row ───
          if (_chatOpen)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.divider),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        enabled: !_isSending,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    _isSending
                        ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                        : IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: AppColors.primary,
                      ),
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.background,
              child: const SafeArea(
                top: false,
                child: Center(
                  child: Text(
                    'Chat closed — this ticket is complete.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}