import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/status_badge.dart';
import 'adsb_chat_screen.dart';

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
  final _notifService = NotificationService();
  Ticket? _ticket;
  bool _isLoading = true;

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

  Future<void> _openResolutionForm() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResolutionSheet(
        rootCauses: _rootCauses,
        solutions: _solutions,
      ),
    );

    if (result == null) return;

    await _service.completeOnSite(
      ticketId: widget.ticketId,
      rootCause: result['rootCause']!,
      solutionApplied: result['solution']!,
      resolutionNotes: result['notes'] ?? '',
      agentEmail: widget.user.email,
      agentName: widget.user.name,
    );

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Job completed. Awaiting client confirmation.'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdsBchatScreenWrapper(
                    ticketId: t.id,
                    user: widget.user,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              title: 'On-Site Details',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Status',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                    StatusBadge(status: t.status),
                  ],
                ),
                const SizedBox(height: 10),
                _row('Client', t.createdByName),
                _row('Contact', '${t.contactName} — ${t.contactPhone}'),
                _row('Site', '${t.siteName}'),
                _row('Address', t.siteLocation),
                _row('Product', t.productType),
                _row('Issue', t.productIssue),
                if (t.description.isNotEmpty) _row('Description', t.description),
              ],
            ),
            if (t.rootCause != null) ...[
              const SizedBox(height: 16),
              _card(
                title: 'Advice from Technical Advisor',
                children: [
                  _row('Root Cause', t.rootCause ?? '—'),
                  _row('Solution Hint', t.solutionApplied ?? '—'),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (t.status == 'in_progress') ...[
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openResolutionForm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Mark as Resolved',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ticket is ${t.statusDisplay.toLowerCase()}.',
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
            width: 90,
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

// Simple wrapper to keep import path consistent
class AdsBchatScreenWrapper extends StatelessWidget {
  final String ticketId;
  final UserModel user;
  const AdsBchatScreenWrapper({
    super.key,
    required this.ticketId,
    required this.user,
  });
  @override
  Widget build(BuildContext context) {
    return AdsbChatScreen(ticketId: ticketId, user: user);
  }
}

class _ResolutionSheet extends StatefulWidget {
  final List<String> rootCauses;
  final List<String> solutions;

  const _ResolutionSheet({
    required this.rootCauses,
    required this.solutions,
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

  @override
  void dispose() {
    _notesController.dispose();
    _customRootCause.dispose();
    _customSolution.dispose();
    super.dispose();
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
            const Text('Resolution Form',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Root Cause',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _rootCause,
              decoration: const InputDecoration(hintText: 'Select root cause'),
              items: widget.rootCauses
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _rootCause = v),
            ),
            if (_rootCause == 'Others') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customRootCause,
                decoration:
                const InputDecoration(hintText: 'Describe root cause'),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Solution Applied',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _solution,
              decoration: const InputDecoration(hintText: 'Select solution'),
              items: widget.solutions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _solution = v),
            ),
            if (_solution == 'Others') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customSolution,
                decoration:
                const InputDecoration(hintText: 'Describe solution'),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Additional Notes (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Any other notes'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_rootCause == null || _solution == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill both fields')),
                    );
                    return;
                  }
                  final rc = _rootCause == 'Others'
                      ? _customRootCause.text.trim()
                      : _rootCause!;
                  final sol = _solution == 'Others'
                      ? _customSolution.text.trim()
                      : _solution!;
                  Navigator.pop(context, {
                    'rootCause': rc,
                    'solution': sol,
                    'notes': _notesController.text.trim(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit Resolution',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}