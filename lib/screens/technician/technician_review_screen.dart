import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/action_dialog.dart';
import '../../widgets/status_badge.dart';
import '../adsb/adsb_chat_screen.dart';

class TechnicianReviewScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;

  const TechnicianReviewScreen({
    super.key,
    required this.ticketId,
    required this.user,
  });

  @override
  State<TechnicianReviewScreen> createState() =>
      _TechnicianReviewScreenState();
}

class _TechnicianReviewScreenState extends State<TechnicianReviewScreen> {
  final _service = TicketService();
  final _notifService = NotificationService();
  Ticket? _ticket;
  bool _isLoading = true;

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

  Future<void> _provideAdvice() async {
    final advice = await ActionDialog.input(
      context: context,
      title: 'Provide Advice to ADSB',
      hint: 'Root cause + recommended solution for on-site work',
      confirmLabel: 'Send Advice',
      maxLines: 5,
    );
    if (advice == null) return;

    await _service.provideAdviceAndAssign(
      ticketId: widget.ticketId,
      advice: advice,
      ttAgentEmail: widget.user.email,
      ttAgentName: widget.user.name,
    );

    if (_ticket != null) {
      await _notifService.addNotification(
        userId: _ticket!.createdBy,
        ticketId: _ticket!.id,
        title: 'On-Site Visit Scheduled',
        body: 'Our team is coming to attend your issue.',
        type: 'schedule',
      );
      await _notifService.addNotification(
        userId: 'adsb@adsb.com',
        ticketId: _ticket!.id,
        title: 'On-Site Required',
        body: 'Ticket ${_ticket!.id} is ready for on-site work.',
        type: 'status_update',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Advice sent. Moved to on-site queue.'),
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
        appBar: AppBar(title: const Text('Ticket')),
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
                  builder: (_) => AdsbChatScreen(
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
              title: 'Issue Summary',
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
                const SizedBox(height: 12),
                _row('Client', '${t.createdByName} (${t.createdByRole})'),
                _row('Contact', '${t.contactName} — ${t.contactPhone}'),
                _row('Site', t.siteName),
                _row('Address', t.siteLocation),
                _row('Product', t.productType),
                _row('Issue', t.productIssue),
                if (t.description.isNotEmpty) _row('Description', t.description),
                _row('Reported', DateFormatter.full(t.createdAt)),
                if (t.assignedToName != null)
                  _row('Escalated by', t.assignedToName!),
              ],
            ),
            const SizedBox(height: 20),

            if (t.status == 'verified') ...[
              const Text(
                'Provide Your Advice',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Analyze the issue. Enter the root cause and recommended solution. The ADSB on-site team will use this when attending.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _provideAdvice,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text(
                    'Provide Advice & Assign On-Site',
                    style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                        'This ticket is currently ${t.statusDisplay.toLowerCase()}.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (t.rootCause != null) ...[
                const SizedBox(height: 16),
                _card(
                  title: 'Your Advice',
                  children: [
                    _row('Root Cause', t.rootCause ?? '—'),
                    _row('Solution Hint', t.solutionApplied ?? '—'),
                  ],
                ),
              ],
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