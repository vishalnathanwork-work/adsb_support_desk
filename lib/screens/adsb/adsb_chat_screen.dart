import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
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
import '../../services/chat_presence_service.dart';
import '../../services/notification_listener.dart';

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
  final _presenceService = ChatPresenceService();

  late final Stream<List<ChatMessage>> _messagesStream;

  Ticket? _ticket;
  bool _isLoadingTicket = true;
  String? _ticketLoadError;
  bool _isSending = false;
  bool _isUploading = false;
  int _lastMessageCount = -1;

  final List<File> _pendingImages = [];
  final List<PickedFile> _pendingDocs = [];

  @override
  void initState() {
    super.initState();
    _messagesStream =
        _chatService.streamMessages(ticketId: widget.ticketId);
    _bootstrap();
    _presenceService.enterChat(widget.ticketId);
    AppNotificationListener().setViewingTicket(widget.ticketId);
  }

  @override
  void dispose() {
    _presenceService.exitChat();
    AppNotificationListener().setViewingTicket(null);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // BOOTSTRAP
  // ═══════════════════════════════════════════════

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _isLoadingTicket = true;
        _ticketLoadError = null;
      });
    }

    try {
      final ticket =
      await _ticketService.getTicketById(widget.ticketId);

      if (!mounted) return;

      if (ticket == null) {
        setState(() {
          _ticket = null;
          _isLoadingTicket = false;
          _ticketLoadError = 'Ticket not found (${widget.ticketId})';
        });
        return;
      }

      // ─── TT access gate ───
      if (widget.user.isTechnician) {
        const ttProducts = [
          'Barrier',
          'Payment Terminal',
          'Intercom'
        ];
        if (!ttProducts.contains(ticket.productType)) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.chatRoleRestricted ??
                    'Access restricted for this product type',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }
      }

      setState(() {
        _ticket = ticket;
        _isLoadingTicket = false;
      });

      try {
        await _chatService.ensureTicketSummary(ticket);
      } catch (e) {
        debugPrint('ensureTicketSummary failed: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('BOOTSTRAP EXCEPTION: $e');
      debugPrint('Stack: $stackTrace');

      if (!mounted) return;

      setState(() {
        _ticket = null;
        _isLoadingTicket = false;
        _ticketLoadError = 'Failed to load ticket: $e';
      });
    }
  }

  // ═══════════════════════════════════════════════
  // CHAT OPEN STATE
  // ═══════════════════════════════════════════════

  bool get _chatOpen {
    if (_ticket == null) return false;

    final status = _ticket!.status.toLowerCase().trim();

    switch (status) {
      case 'closed':
      case 'cancelled':
        return false;
      case 'pending':
      case 'verified':
      case 'pending_onsite':
      case 'in_progress':
      case 'resolved':
      case 'reopened':
        return true;
      default:
        return false;
    }
  }

  // ═══════════════════════════════════════════════
  // SCROLL
  // ═══════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════
  // ATTACHMENTS
  // ═══════════════════════════════════════════════

  int get _attachmentCount =>
      _pendingImages.length + _pendingDocs.length;

  void _showAttachSheet() {
    final t = AppLocalizations.of(context)!;

    if (_attachmentCount >= AppConfig.maxChatAttachments) {
      _snack(t.attachmentsLimit('${AppConfig.maxChatAttachments}'));
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.chatAttachTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.chatChoosePhotos),
              onTap: () {
                Navigator.pop(context);
                _pickGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(t.chooseDocument),
              subtitle: Text(
                t.chooseDocumentHint,
                style: const TextStyle(fontSize: 11),
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
    final t = AppLocalizations.of(context)!;
    if (_attachmentCount >= AppConfig.maxChatAttachments) {
      _snack(t.attachmentsLimit('${AppConfig.maxChatAttachments}'));
      return;
    }
    final file = await _imageService.pickFromCamera();
    if (file != null && mounted) {
      setState(() => _pendingImages.add(file));
    }
  }

  Future<void> _pickGallery() async {
    final t = AppLocalizations.of(context)!;
    final remaining =
        AppConfig.maxChatAttachments - _attachmentCount;
    if (remaining <= 0) {
      _snack(t.attachmentsLimit('${AppConfig.maxChatAttachments}'));
      return;
    }
    final files =
    await _imageService.pickFromGallery(limit: remaining);
    if (files.isNotEmpty && mounted) {
      setState(() => _pendingImages.addAll(files));
    }
  }

  Future<void> _pickDocument() async {
    final t = AppLocalizations.of(context)!;
    if (_attachmentCount >= AppConfig.maxChatAttachments) {
      _snack(t.attachmentsLimit('${AppConfig.maxChatAttachments}'));
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

  // ═══════════════════════════════════════════════
  // SEND
  // ═══════════════════════════════════════════════

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachmentCount == 0) return;
    if (_isSending || _isUploading) return;
    if (!_chatOpen) return;

    setState(() => _isSending = true);

    final isAdsb = widget.user.role == 'adsb';
    if (isAdsb && _ticket != null && _ticket!.status == 'pending') {
      await _ticketService.autoEscalateIfNeeded(
        ticketId: widget.ticketId,
        reason: text.isEmpty ? 'Attachment sent' : text,
        adsbEmail: widget.user.email,
        adsbName: widget.user.name,
      );

      final fresh =
      await _ticketService.getTicketById(widget.ticketId);
      if (mounted) setState(() => _ticket = fresh);
    }

    List<String> imageUrls = [];
    if (_pendingImages.isNotEmpty) {
      setState(() => _isUploading = true);
      imageUrls = await _imageService.uploadImages(
        files: _pendingImages,
        folder: 'chat_attachments',
        ticketId: widget.ticketId,
      );
    }

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

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t.chatWith} — ${widget.ticketId}',
              style: const TextStyle(fontSize: 16),
            ),
            if (_ticket != null)
              Text(
                '${_ticket!.siteName} · ${_ticket!.laneName} (${_ticket!.laneDirectionDisplay})',
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
          // ─── Read-only banner (only when ticket loaded AND closed) ───
          if (_ticket != null && !_chatOpen) _readOnlyBanner(t),

          // ⭐ Hide summary card when keyboard is open to avoid overflow
          if (_ticket != null && !keyboardOpen) _summaryCard(_ticket!, t),

          // ─── Messages list / Loading / Error state ───
          Expanded(
            child: _isLoadingTicket
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading chat...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : _ticketLoadError != null || _ticket == null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _ticketLoadError ??
                          'Failed to load ticket',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _bootstrap,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
                : StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading messages: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                final messages = (snapshot.data ?? [])
                    .where((m) => !m.isSystem)
                    .toList();

                if (messages.isEmpty) {
                  return Center(child: Text(t.noMessagesYet));
                }

                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMe =
                        m.senderEmail == widget.user.email;
                    return ChatBubble(
                      message: m,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),

          // ─── Pending attachments preview ───
          if (_attachmentCount > 0)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: _buildPendingAttachments(),
            ),

          // ─── Bottom: three states — loading / open / closed ───
          if (_isLoadingTicket)
            _loadingBottomBar()
          else if (_chatOpen)
            _chatInputBar(t)
          else
            _closedBottomBar(t),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // BOTTOM BARS
  // ═══════════════════════════════════════════════

  Widget _loadingBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: const SafeArea(
        top: false,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  /// Shown when chat is open.
  /// Keyboard-aware: uses viewInsets.bottom instead of SafeArea.
  /// Shown when chat is open.
  /// Scaffold handles the keyboard resize — no manual viewInsets needed.
  Widget _chatInputBar(AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
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
            tooltip: t.attachFile,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              enabled: !_isSending,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: t.chatTypeMessage,
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
    );
  }

  /// Shown when the ticket is closed or cancelled.
  Widget _closedBottomBar(AppLocalizations t) {
    final status = _ticket?.status.toLowerCase().trim() ?? '';
    final message = status == 'cancelled'
        ? 'This ticket was cancelled. Chat is read-only.'
        : t.chatClosedBanner;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Top read-only banner shown when the ticket is closed/cancelled.
  Widget _readOnlyBanner(AppLocalizations t) {
    final status = _ticket?.status.toLowerCase().trim() ?? '';
    final message = status == 'cancelled'
        ? 'This ticket was cancelled. Chat is read-only.'
        : t.chatReadOnly;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: AppColors.textSecondary.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // TICKET SUMMARY CARD — collapsed by default + height-capped
  // ═══════════════════════════════════════════════

  Widget _summaryCard(Ticket ticket, AppLocalizations t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      // ⭐ Fixed height — always the same size, no expand/collapse surprise
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header row (always visible) ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.ticketSummary,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(status: ticket.status),
              ],
            ),
          ),
          const Divider(height: 1),

          // ─── Scrollable content ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sumHeader(t.clientDetails),
                  _sumRow(
                    t.nameLabel,
                    '${ticket.createdByName} (${ticket.createdByRoleLabel})',
                  ),
                  _sumRow(
                    t.contactLabel,
                    '${ticket.contactName} · ${ticket.contactPhone}',
                  ),
                  const SizedBox(height: 8),
                  _sumHeader(t.ticketDetails),
                  _sumRow(t.adminProductLabel, ticket.productType),
                  _sumRow(t.adminIssueLabel, ticket.productIssue),
                  _sumRow(
                    t.siteLabel,
                    '${ticket.siteName} — ${ticket.siteLocation}',
                  ),
                  _sumRow(
                    t.parkingLabel,
                    '${ticket.laneName} (${ticket.laneDirectionDisplay})',
                  ),
                  _sumRow(
                    t.reportedLabel,
                    DateFormatter.full(ticket.createdAt),
                  ),
                  if (ticket.description.isNotEmpty)
                    _sumRow(t.notes, ticket.description),
                  if (ticket.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sumHeader(t.reportedPhotos),
                    ImageGallery(
                      urls: ticket.imageUrls,
                      thumbSize: 64,
                      title: t.reportedPhotos,
                    ),
                  ],
                  if (ticket.completionImageUrl != null &&
                      ticket.completionImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sumHeader(t.completionEvidence),
                    ImageGallery(
                      urls: [ticket.completionImageUrl!],
                      thumbSize: 64,
                      title: t.completionEvidence,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
                const Icon(
                  Icons.insert_drive_file,
                  size: 20,
                  color: AppColors.primary,
                ),
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