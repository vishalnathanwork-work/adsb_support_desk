import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
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
    final t = await _service.getTicketById(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _ticket = t;
      _isLoading = false;
    });
  }

  Future<void> _claimJob() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Claim this job?'),
        content: const Text(
            'You will be assigned to this on-site job. The timer starts now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Claim'),
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
      const SnackBar(
        content: Text('Job claimed. Good luck!'),
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

    // Update chat summary with completion photo
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
      const SnackBar(
        content: Text('Job completed. Awaiting owner confirmation.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job')),
        body: const Center(child: Text('Ticket not found')),
      );
    }

    final t = _ticket!;
    final isUnclaimed = t.status == 'pending_onsite';
    final isMine = t.assignedTo == widget.user.email;
    final isInProgress = t.status == 'in_progress' && isMine;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Open chat',
            onPressed: _openChat,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              title: 'Job Details',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Status',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
                      ),
                    ),
                    StatusBadge(status: t.status),
                  ],
                ),
                const SizedBox(height: 10),
                _row('Client', t.createdByName),
                _row('Contact', '${t.contactName} — ${t.contactPhone}'),
                _row('Site', t.siteName),
                _row('Address', t.siteLocation),
                _row('Parking',
                    '${t.laneName} (${t.laneDirectionDisplay})'),
                _row('Product', t.productType),
                if (t.productIssue.isNotEmpty)
                  _row('Issue', t.productIssue),
                if (t.description.isNotEmpty)
                  _row('Description', t.description),
              ],
            ),

            if (t.rootCause != null || t.solutionApplied != null) ...[
              const SizedBox(height: 16),
              _card(
                title: 'Advice from Technical Advisor',
                children: [
                  if (t.rootCause != null)
                    _row('Root Cause Hint', t.rootCause!),
                  if (t.solutionApplied != null &&
                      t.solutionApplied != 'Pending on-site work')
                    _row('Solution Hint', t.solutionApplied!),
                ],
              ),
            ],

            if (t.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              _card(
                title: 'Reported Photo Evidence',
                children: [
                  _imageGrid(t.imageUrls),
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
                      color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.warning, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This job has not been claimed yet. Claim it to start.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isWorking ? null : _claimJob,
                  icon: const Icon(Icons.handyman_outlined),
                  label: _isWorking
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Claim Job',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
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
                child: ElevatedButton.icon(
                  onPressed: _isWorking ? null : _openResolutionForm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: _isWorking
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Job Completed',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
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
                        'This job is ${t.statusDisplay.toLowerCase()}.',
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
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
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
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// RESOLUTION SHEET — with REQUIRED completion evidence
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
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickEvidence();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
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
    if (_rootCause == null || _solution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill root cause and solution'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_evidenceImage == null) {
      setState(() => _evidenceError = 'Completion photo is required');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach a completion photo'),
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
        const SnackBar(
          content: Text('Failed to upload evidence. Try again.'),
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
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
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
            const Text(
              'Job Completion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ─── Root cause ───
            const Text(
              'Root Cause',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _rootCause,
              decoration: const InputDecoration(
                hintText: 'Select root cause',
              ),
              items: widget.rootCauses
                  .map((r) =>
                  DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _rootCause = v),
            ),
            if (_rootCause == 'Others') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customRootCause,
                decoration: const InputDecoration(
                  hintText: 'Describe root cause',
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ─── Solution ───
            const Text(
              'Solution Applied',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _solution,
              decoration: const InputDecoration(
                hintText: 'Select solution',
              ),
              items: widget.solutions
                  .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _solution = v),
            ),
            if (_solution == 'Others') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customSolution,
                decoration: const InputDecoration(
                  hintText: 'Describe solution',
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ─── Notes ───
            const Text(
              'Additional Notes (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any other notes',
              ),
            ),

            const SizedBox(height: 16),

            // ─── Completion Evidence (REQUIRED) ───
            Row(
              children: [
                const Text(
                  'Completion Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
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
            const Text(
              'Take a photo showing the resolved work.',
              style: TextStyle(
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
                  padding: const EdgeInsets.symmetric(vertical: 20),
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
                        'Add completion photo',
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
                      onTap: () =>
                          setState(() => _evidenceImage = null),
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
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Photo attached',
                            style: TextStyle(
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

            // ─── Submit ───
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
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'Submit Completion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}