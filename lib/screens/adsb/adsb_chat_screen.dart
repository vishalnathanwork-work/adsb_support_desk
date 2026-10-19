import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/image_service.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/status_badge.dart';

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
  final _imageService = ImageService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Ticket? _ticket;
  bool _isSending = false;
  bool _isUploading = false;

  // Staged attachments for the next message
  final List<File> _pendingImages = [];
  final List<PickedFile> _pendingDocs = [];

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

  bool get _chatOpen {
    if (_ticket == null) return false;
    return _ticket!.status != 'closed' && _ticket!.status != 'cancelled';
  }

  int get _attachmentCount => _pendingImages.length + _pendingDocs.length;

  // ─────────────────────────────────────────
  // ATTACH — picker source sheet
  // ─────────────────────────────────────────

  void _showAttachSheet() {
    if (_attachmentCount >= AppConfig.maxChatAttachments) {
      _snack(
          'Maximum ${AppConfig.maxChatAttachments} attachments per message');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Attach',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose Photos'),
              onTap: () {
                Navigator.pop(context);
                _pickGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Choose Document'),
              subtitle: const Text(
                'PDF, Word, Excel, ZIP, etc.',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCamera() async {
    if (_attachmentCount >= AppConfig.maxChatAttachments) {
      _snack('Maximum ${AppConfig.maxChatAttachments} attachments');
      return;
    }
    final file = await _imageService.pickFromCamera();
    if (file != null && mounted) {
      setState(() => _pendingImages.add(file));
    }
  }

  Future<void> _pickGallery() async {
    final remaining = AppConfig.maxChatAttachments - _attachmentCount;
    if (remaining <= 0) {
      _snack('Maximum ${AppConfig.maxChatAttachments} attachments');
      return;
    }
    final files = await _imageService.pickFromGallery(limit: remaining);
    if (files.isNotEmpty && mounted) {
      setState(() => _pendingImages.addAll(files));
    }
  }

  Future<void> _pickDocument() async {
    if (_attachmentCount >= AppConfig.maxChatAttachments) {
      _snack('Maximum ${AppConfig.maxChatAttachments} attachments');
      return;
    }
    final doc = await _imageService.pickDocument();
    if (doc != null && mounted) {
      setState(() => _pendingDocs.add(doc));
    }
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  void _removePendingDoc(int index) {
    setState(() => _pendingDocs.removeAt(index));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ─────────────────────────────────────────
  // SEND
  // ─────────────────────────────────────────

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachmentCount == 0) return;
    if (_isSending || _isUploading) return;
    if (!_chatOpen) return;

    setState(() => _isSending = true);

    // ─── Auto-escalate on first ADSB message on a pending ticket ───
    final isAdsb = widget.user.role == 'adsb';
    if (isAdsb && _ticket != null && _ticket!.status == 'pending') {
      await _ticketService.autoEscalateIfNeeded(
        ticketId: widget.ticketId,
        reason: text.isEmpty ? 'Attachment sent' : text,
        adsbEmail: widget.user.email,
        adsbName: widget.user.name,
      );

      final fresh = await _ticketService.getTicketById(widget.ticketId);
      if (mounted) setState(() => _ticket = fresh);
    }

    // Upload images
    List<String> imageUrls = [];
    if (_pendingImages.isNotEmpty) {
      setState(() => _isUploading = true);
      imageUrls = await _imageService.uploadImages(
        files: _pendingImages,
        folder: 'chat_attachments',
        ticketId: widget.ticketId,
      );
    }

    // Upload documents
    List<String> attachmentUrls = [];
    List<String> attachmentNames = [];
    for (final doc in _pendingDocs) {
      final url = await _imageService.uploadDocument(
        file: doc.file,
        ticketId: widget.ticketId,
        originalName: doc.name,
      );
      if (url != null) {
        attachmentUrls.add(url);
        attachmentNames.add(doc.name);
      }
    }

    _controller.clear();
    _pendingImages.clear();
    _pendingDocs.clear();

    await _chatService.sendMessage(
      ticketId: widget.ticketId,
      senderEmail: widget.user.email,
      senderName: widget.user.name,
      senderRole: widget.user.role,
      message: text,
      imageUrls: imageUrls,
      attachmentUrls: attachmentUrls,
      attachmentNames: attachmentNames,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _isUploading = false;
    });
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────

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
                  Icon(Icons.lock_outline,
                      size: 14, color: AppColors.textSecondary),
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

          // ─── Ticket summary card (shown before the chat) ───
          // To show it only to internal staff, use:
          // if (_ticket != null && widget.user.isInternal) ...
          if (_ticket != null) _summaryCard(_ticket!),

          // ─── Messages ───
          Expanded(
            child: _ticket == null
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

                // Hide old auto-posted "TICKET SUMMARY" system
                // messages — the summary card replaces them.
                final messages = (snapshot.data ?? [])
                    .where((m) => !m.isSystem)
                    .toList();

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

          // ─── Pending attachments preview ───
          if (_attachmentCount > 0)
            Container(
              color: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildPendingAttachments(),
            ),

          // ─── Input row ───
          if (_chatOpen)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.divider),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: AppColors.primary,
                      onPressed:
                      _attachmentCount >= AppConfig.maxChatAttachments
                          ? null
                          : _showAttachSheet,
                      tooltip: 'Attach file',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        enabled: !_isSending,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    _isSending || _isUploading
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

  // ═══════════════════════════════════════════════
  // TICKET SUMMARY CARD
  // ═══════════════════════════════════════════════

  Widget _summaryCard(Ticket t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Ticket Summary',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusBadge(status: t.status),
            ],
          ),
          children: [
            // Scrolls inside the card so it never pushes the chat off-screen
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sumHeader('Client Details'),
                    _sumRow('Name',
                        '${t.createdByName} (${t.createdByRoleLabel})'),
                    _sumRow(
                        'Contact', '${t.contactName} · ${t.contactPhone}'),
                    const SizedBox(height: 8),

                    _sumHeader('Ticket Details'),
                    _sumRow('Product', t.productType),
                    _sumRow('Issue', t.productIssue),
                    _sumRow('Site', '${t.siteName} — ${t.siteLocation}'),
                    _sumRow('Parking',
                        '${t.laneName} (${t.laneDirectionDisplay})'),
                    _sumRow('Reported', DateFormatter.full(t.createdAt)),
                    if (t.description.isNotEmpty)
                      _sumRow('Notes', t.description),

                    // Photos uploaded by owner / operator (Firebase Storage)
                    if (t.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sumHeader('Reported Photos'),
                      ImageGallery(
                        urls: t.imageUrls,
                        thumbSize: 64,
                        title: 'Reported Photos',
                      ),
                    ],

                    // Photo uploaded by on-site team after completion
                    if (t.completionImageUrl != null &&
                        t.completionImageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sumHeader('Completion Evidence'),
                      ImageGallery(
                        urls: [t.completionImageUrl!],
                        thumbSize: 64,
                        title: 'Completion Evidence',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sumHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _sumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PENDING ATTACHMENTS
  // ═══════════════════════════════════════════════

  Widget _buildPendingAttachments() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._pendingImages.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return _pendingThumb(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  file,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              onRemove: () => _removePendingImage(index),
            );
          }),
          ..._pendingDocs.asMap().entries.map((entry) {
            final index = entry.key;
            final doc = entry.value;
            return _pendingDocThumb(
              name: doc.name,
              onRemove: () => _removePendingDoc(index),
            );
          }),
        ],
      ),
    );
  }

  Widget _pendingThumb({
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          child,
          Positioned(
            top: -2,
            right: -2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingDocThumb({
    required String name,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.insert_drive_file,
                    size: 20, color: AppColors.primary),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(fontSize: 8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            top: -2,
            right: -2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}