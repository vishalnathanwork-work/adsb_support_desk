import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
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
  bool _markedReviewed = false;

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

  // ─────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────

  Future<void> _openInternalChat() async {
    if (_ticket == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdsbChatScreen(
          ticketId: _ticket!.id,
          user: widget.user,
          channel: 'internal',
        ),
      ),
    );
    _load();
  }

  Future<void> _callAdsbAgent() async {
    const adsbPhone = '+60 12-345 6791';
    final uri = Uri.parse('tel:$adsbPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot call ADSB agent')),
      );
    }
  }

  Future<void> _markReviewed() async {
    if (_ticket == null || _markedReviewed) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark review complete?'),
        content: const Text(
          'This confirms you have finished advising on this ticket. '
              'The ADSB team will decide whether to resolve remotely or send on-site.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.success,
            ),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _service.markTTReviewed(
      ticketId: widget.ticketId,
      ttEmail: widget.user.email,
      ttName: widget.user.name,
    );

    if (_ticket != null) {
      await _notifService.addNotification(
        userId: _ticket!.assignedTo ?? 'adsb@adsb.com',
        ticketId: _ticket!.id,
        title: 'TT Review Complete',
        body: 'TT has provided their advice on ${_ticket!.id}.',
        type: 'status_update',
      );
    }

    if (!mounted) return;
    setState(() => _markedReviewed = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked as reviewed. ADSB team has been notified.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────

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
    final alreadyReviewed =
        t.ttSolutionProvidedAt != null || _markedReviewed;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.id),
        backgroundColor: const Color(0xFF5E35B1),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined),
            tooltip: 'Call ADSB agent',
            onPressed: _callAdsbAgent,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _escalationBanner(t),
            const SizedBox(height: 16),
            _card(
              title: 'Ticket Details',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    StatusBadge(status: t.status),
                  ],
                ),
                const SizedBox(height: 12),
                _row('Client', t.createdByName),
                _row('Contact', '${t.contactName} — ${t.contactPhone}'),
                _row('Site', t.siteName),
                _row('Location', t.siteLocation),
                _row(
                  'Parking',
                  '${t.laneName} (${t.laneDirectionDisplay})',
                ),
                _row('Product', t.productType),
                _row('Issue', t.productIssue),
                if (t.description.isNotEmpty)
                  _row('Description', t.description),
                _row('Reported', DateFormatter.full(t.createdAt)),
              ],
            ),
            if (t.escalationReason != null) ...[
              const SizedBox(height: 12),
              _card(
                title: 'Reason for Escalation',
                children: [
                  Text(
                    t.escalationReason!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  if (t.assignedToName != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Escalated by ${t.assignedToName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Discuss with ADSB',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chat internally with the ADSB agent who escalated this ticket. '
                  'Your messages are private — clients never see them.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _openInternalChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 22),
                label: const Text(
                  'Open Internal Chat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
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
              child: OutlinedButton.icon(
                onPressed: _callAdsbAgent,
                icon: const Icon(Icons.phone_in_talk_outlined, size: 20),
                label: const Text(
                  'Call ADSB Agent',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (alreadyReviewed) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Review marked complete. ADSB has been notified.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                height: 48,
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _markReviewed,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text(
                    'Mark Review Complete',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Use this after providing your advice',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  Widget _escalationBanner(Ticket t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5E35B1), Color(0xFF4527A0)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_upward,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escalated by ADSB',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.assignedToName ?? 'ADSB Support',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required List<Widget> children,
  }) {
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
              color: Color(0xFF5E35B1),
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
            width: 90,
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