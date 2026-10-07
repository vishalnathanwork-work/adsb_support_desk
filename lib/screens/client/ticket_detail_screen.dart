import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/status_badge.dart';
import '../adsb/adsb_chat_screen.dart';         // ← reuse the same chat screen

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.user,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _service = TicketService();
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

  Future<void> _openChat() async {
    if (_ticket == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdsbChatScreen(
          ticketId: _ticket!.id,
          user: widget.user,
          channel: 'ticket',
        ),
      ),
    );
    _load();
  }

  Future<void> _confirmResolution() async {
    await _service.confirmResolution(widget.ticketId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ticket closed. Thank you!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _reopen() async {
    await _service.reopenTicket(widget.ticketId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ticket reopened.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this ticket?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _service.cancelTicket(widget.ticketId);
      await _load();
    }
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
          if (t.isActive)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _cancel,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.productType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusBadge(status: t.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.productIssue,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.statusDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── CHAT BUTTON (visible during active handling) ───
            if (t.isActive)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text(
                    'Chat with ADSB Team',
                    style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
            const SizedBox(height: 16),

            // Details
            _section('Ticket Details'),
            _infoTile('Site', '${t.siteName} — ${t.siteLocation}'),
            _infoTile('Contact', '${t.contactName} (${t.contactPhone})'),
            _infoTile('Reported', DateFormatter.full(t.createdAt)),
            _infoTile(
              'Time to Resolve',
              Ticket.formatDuration(t.totalResolutionTime),
            ),
            if (t.adsbPickupAt != null && t.workCompletedAt != null)
              _infoTile(
                'On-Site Duration',
                Ticket.formatDuration(t.onsiteWorkDuration),
              ),
            if (t.description.isNotEmpty)
              _infoTile('Description', t.description),

            const SizedBox(height: 16),

            // Resolution
            if (t.resolvedAt != null) ...[
              _section('Resolution'),
              _infoTile('Root Cause', t.rootCause ?? '—'),
              _infoTile('Solution', t.solutionApplied ?? '—'),
              if (t.resolutionNotes != null &&
                  t.resolutionNotes!.isNotEmpty)
                _infoTile('Notes', t.resolutionNotes!),
              _infoTile('Resolved At', DateFormatter.full(t.resolvedAt!)),
              const SizedBox(height: 16),
            ],

            // Confirmation actions
            if (t.status == 'resolved') ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _confirmResolution,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Resolution'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _reopen,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reopen Ticket'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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