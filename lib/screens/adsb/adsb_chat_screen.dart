import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/empty_state.dart';

class AdsbChatScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;
  final String channel; // 'ticket' | 'internal'

  const AdsbChatScreen({
    super.key,
    required this.ticketId,
    required this.user,
    this.channel = 'ticket',
  });

  @override
  State<AdsbChatScreen> createState() => _AdsbChatScreenState();
}

class _AdsbChatScreenState extends State<AdsbChatScreen> {
  final _service = ChatService();
  final _ticketService = TicketService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Ticket? _ticket;
  bool _summaryReady = false;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    final t = await _ticketService.getTicketById(widget.ticketId);
    if (!mounted) return;
    setState(() => _ticket = t);

    if (t != null) {
      await _service.ensureTicketSummary(
        ticket: t,
        channel: widget.channel,
      );
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await _service.sendMessage(
      ticketId: widget.ticketId,
      channel: widget.channel,
      senderEmail: widget.user.email,
      senderName: widget.user.name,
      senderRole: widget.user.role,
      message: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInternal = widget.channel == 'internal';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isInternal
              ? 'Internal — ${widget.ticketId}'
              : 'Chat — ${widget.ticketId}',
        ),
        backgroundColor: isInternal
            ? const Color(0xFF5E35B1)
            : AppColors.primary,
        actions: [
          if (isInternal)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'ADSB ↔ TT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Warning banner for internal chat
          if (isInternal)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFF5E35B1).withOpacity(0.1),
              child: Row(
                children: const [
                  Icon(Icons.lock, size: 14, color: Color(0xFF5E35B1)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Private channel — client cannot see this conversation.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5E35B1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _service.streamMessages(
                ticketId: widget.ticketId,
                channel: widget.channel,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_summaryReady) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty && _summaryReady) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    subtitle: 'Start the conversation',
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: isInternal
                      ? const Color(0xFF5E35B1).withOpacity(0.3)
                      : AppColors.divider,
                  width: isInternal ? 2 : 1,
                ),
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
                      decoration: InputDecoration(
                        hintText: isInternal
                            ? 'Internal note to TT team...'
                            : 'Type a message...',
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: isInternal
                          ? const Color(0xFF5E35B1)
                          : AppColors.primary,
                    ),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}