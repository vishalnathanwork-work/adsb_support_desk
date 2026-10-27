import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/image_service.dart';
import '../../services/notification_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/status_badge.dart';
import '../adsb/adsb_chat_screen.dart';

class OnsiteJobScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;

  const OnsiteJobScreen({
    super.key,
    required this.ticketId,
    required this.user,
  });

  @override
  State<OnsiteJobScreen> createState() => _OnsiteJobScreenState();
}

class _OnsiteJobScreenState extends State<OnsiteJobScreen> {
  final _service = TicketService();
  final _imageService = ImageService();
  final _chatService = ChatService();
  final _notifService = NotificationService();
  Ticket? _ticket;
  bool _isLoading = true;
  bool _isWorking = false;

  static const _rootCauses = [
    'Wiring / Connection issue',
    'Hardware failure',
    'Software / Firmware',
    'Configuration error',
    'Physical damage',
    'Environmental (heat / water / dust)',
    'User error',
    'Power supply',
    'Others',
  ];

  static const _solutions = [
    'Replaced component',
    'Rewired / reconnected',
    'Updated firmware',
    'Reset / reboot',
    'Reconfigured settings',
    'Cleaned / serviced',
    'Tightened / adjusted',
    'Replaced whole unit',
    'No physical fix needed',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ticket = await _service.getTicketById(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _ticket = ticket;
      _isLoading = false;
    });
  }

  Future<void> _claimJob() async {
    final t = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.onsiteClaimTitle),
        content: Text(t.onsiteClaimMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.adminCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.onsiteClaim),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isWorking = true);
    await _service.claimOnsiteJob(
      ticketId: widget.ticketId,
      adsbEmail: widget.user.email,
      adsbName: widget.user.name,
    );
    await _load();

    if (!mounted) return;
    setState(() => _isWorking = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.onsiteClaimed),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdsbChatScreen(
          ticketId: widget.ticketId,
          user: widget.user,
        ),
      ),
    );
  }

  Future<void> _openResolutionForm() async {
    final t = AppLocalizations.of(context)!;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResolutionSheet(
        rootCauses: _rootCauses,
        solutions: _solutions,
        ticketId: widget.ticketId,
        imageService: _imageService,
      ),
    );

    if (result == null) return;

    setState(() => _isWorking = true);

    await _service.completeOnSite(
      ticketId: widget.ticketId,
      rootCause: result['rootCause'] as String,
      solutionApplied: result['solution'] as String,
      resolutionNotes: (result['notes'] as String?) ?? '',
      agentEmail: widget.user.email,
      agentName: widget.user.name,
      completionImageUrl: result['imageUrl'] as String?,
    );

    final imageUrl = result['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final updated = await _service.getTicketById(widget.ticketId);
      if (updated != null) {
        await _chatService.refreshSummaryImages(updated);
      }
    }

    if (_ticket != null) {
      await _notifService.addNotification(
        userId: _ticket!.createdBy,
        ticketId: _ticket!.id,
        title: 'Issue Resolved',
        body: 'Your issue has been resolved. Please confirm.',
        type: 'resolved',
      );
    }

    if (!mounted) return;
    setState(() => _isWorking = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.onsiteJobCompletedSuccess),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ticket == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.onsiteJobNotFoundTitle)),
        body: Center(child: Text(t.onsiteTicketNotFound)),
      );
    }

    final ticket = _ticket!;
    final isUnclaimed = ticket.status == 'pending_onsite';
    final isMine = ticket.assignedTo == widget.user.email;
    final isInProgress = ticket.status == 'in_progress' && isMine;

    return Scaffold(
      appBar: AppBar(title: Text(ticket.id)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              title: t.onsiteJobDetails,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.statusLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    StatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 10),
                _row(t.clientLabel, ticket.createdByName),
                _row(
                  t.contactLabel,
                  '${ticket.contactName} — ${ticket.contactPhone}',
                ),
                _row(t.onsiteSiteLabel, ticket.siteName),
                _row(t.onsiteAddressLabel, ticket.siteLocation),
                _row(t.adminLanesLabel, ticket.lanesSummary),
                _row(t.adminProductLabel, ticket.productType),
                if (ticket.productIssue.isNotEmpty)
                  _row(t.adminIssueLabel, ticket.productIssue),
                if (ticket.description.isNotEmpty)
                  _row(t.descriptionLabel, ticket.description),
              ],
            ),

            if (ticket.rootCause != null ||
                ticket.solutionApplied != null) ...[
              const SizedBox(height: 16),
              _card(
                title: t.onsiteAdviceTitle,
                children: [
                  if (ticket.rootCause != null)
                    _row(t.onsiteRootCauseHint, ticket.rootCause!),
                  if (ticket.solutionApplied != null &&
                      ticket.solutionApplied != 'Pending on-site work')
                    _row(t.onsiteSolutionHint, ticket.solutionApplied!),
                ],
              ),
            ],

            if (ticket.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              _card(
                title: t.onsiteReportedPhotos,
                children: [
                  _imageGrid(ticket.imageUrls),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ─── Actions ───
            if (isUnclaimed) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.onsiteJobUnclaimedBanner,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isWorking ? null : _claimJob,
                  icon: const Icon(Icons.handyman_outlined),
                  label: _isWorking
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    t.onsiteClaimJob,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else if (isInProgress) ...[
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    t.openChat,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isWorking ? null : _openResolutionForm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: _isWorking
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    t.onsiteJobCompleted,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.onsiteJobStatus(
                            ticket.statusDisplay.toLowerCase()),
                        style: const TextStyle(fontSize: 13),
                      ),
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

  Widget _imageGrid(List<String> urls) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls.map((url) {
        if (url.startsWith('local://')) {
          final path = url.replaceFirst('local://', '');
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: AppColors.divider,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 80,
              height: 80,
              color: AppColors.divider,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// RESOLUTION SHEET — overflow-safe
// ═══════════════════════════════════════════════

class _ResolutionSheet extends StatefulWidget {
  final List<String> rootCauses;
  final List<String> solutions;
  final String ticketId;
  final ImageService imageService;

  const _ResolutionSheet({
    required this.rootCauses,
    required this.solutions,
    required this.ticketId,
    required this.imageService,
  });

  @override
  State<_ResolutionSheet> createState() => _ResolutionSheetState();
}

class _ResolutionSheetState extends State<_ResolutionSheet> {
  String? _rootCause;
  String? _solution;
  final _notesController = TextEditingController();
  final _customRootCause = TextEditingController();
  final _customSolution = TextEditingController();

  File? _evidenceImage;
  bool _uploading = false;
  String? _evidenceError;

  @override
  void dispose() {
    _notesController.dispose();
    _customRootCause.dispose();
    _customSolution.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final file = await widget.imageService.pickFromCamera();
    if (file != null && mounted) {
      setState(() {
        _evidenceImage = file;
        _evidenceError = null;
      });
    }
  }

  Future<void> _pickEvidenceFromGallery() async {
    final files = await widget.imageService.pickFromGallery(limit: 1);
    if (files.isNotEmpty && mounted) {
      setState(() {
        _evidenceImage = files.first;
        _evidenceError = null;
      });
    }
  }

  void _showSourceSheet() {
    final t = AppLocalizations.of(context)!;
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
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(t.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickEvidence();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickEvidenceFromGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;

    if (_rootCause == null || _solution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.completionPleaseFill),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_evidenceImage == null) {
      setState(() => _evidenceError = t.completionPhotoError);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.completionPleaseAttach),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rc = _rootCause == 'Others'
        ? _customRootCause.text.trim()
        : _rootCause!;
    final sol = _solution == 'Others'
        ? _customSolution.text.trim()
        : _solution!;

    setState(() => _uploading = true);
    final imageUrl = await widget.imageService.uploadImage(
      file: _evidenceImage!,
      folder: 'completion_evidence',
      ticketId: widget.ticketId,
    );
    if (!mounted) return;
    setState(() => _uploading = false);

    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.completionUploadFailed),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, {
      'rootCause': rc,
      'solution': sol,
      'notes': _notesController.text.trim(),
      'imageUrl': imageUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.completionFormTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Root cause ───
                  Text(
                    t.completionRootCause,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _rootCause,
                    decoration: InputDecoration(
                      hintText: t.completionSelectRootCause,
                    ),
                    items: widget.rootCauses
                        .map((r) => DropdownMenuItem(
                        value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _rootCause = v),
                  ),
                  if (_rootCause == 'Others') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customRootCause,
                      decoration: InputDecoration(
                        hintText: t.describeRootCauseHint,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ─── Solution ───
                  Text(
                    t.completionSolution,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _solution,
                    decoration: InputDecoration(
                      hintText: t.completionSelectSolution,
                    ),
                    items: widget.solutions
                        .map((s) => DropdownMenuItem(
                        value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _solution = v),
                  ),
                  if (_solution == 'Others') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customSolution,
                      decoration: InputDecoration(
                        hintText: t.describeSolutionHint,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ─── Notes ───
                  Text(
                    t.completionNotes,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: t.completionNotesHint,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Evidence (required) ───
                  Row(
                    children: [
                      Text(
                        t.completionPhotoLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          t.required.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.completionPhotoRequired,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_evidenceImage == null)
                    InkWell(
                      onTap: _showSourceSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: _evidenceError != null
                              ? AppColors.error.withOpacity(0.06)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _evidenceError != null
                                ? AppColors.error
                                : AppColors.divider,
                            width: _evidenceError != null ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 28,
                              color: _evidenceError != null
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.completionAddPhoto,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _evidenceError != null
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            if (_evidenceError != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _evidenceError!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _evidenceImage!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => setState(
                                    () => _evidenceImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  t.completionPhotoAttached,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _uploading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _uploading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        t.completionSubmit,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}