import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/action_dialog.dart';
import '../../widgets/status_badge.dart';
import 'adsb_chat_screen.dart';

class AdsbTicketActionScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;

  const AdsbTicketActionScreen({
    super.key,
    required this.ticketId,
    required this.user,
  });

  @override
  State<AdsbTicketActionScreen> createState() =>
      _AdsbTicketActionScreenState();
}

class _AdsbTicketActionScreenState extends State<AdsbTicketActionScreen> {
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

  // ─────────────────────────────────────────
  // CONTACT
  // ─────────────────────────────────────────

  Future<void> _callClient() async {
    if (_ticket == null) return;
    final phone = _ticket!.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot call $phone')),
      );
    }
  }

  Future<void> _openClientChat() async {
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

  // ─────────────────────────────────────────
  // OUTCOMES
  // ─────────────────────────────────────────

  /// Option A — Resolve Remotely.
  /// Works whether or not TT was consulted.
  Future<void> _resolveRemotely() async {
    final ok = await ActionDialog.confirm(
      context: context,
      title: 'Resolve Remotely?',
      message:
      'Mark this ticket as resolved. The client will be asked to confirm.',
      confirmLabel: 'Yes, Resolve',
      confirmColor: AppColors.success,
    );
    if (!ok) return;

    await _service.resolveRemotely(
      widget.ticketId,
      widget.user.email,
      widget.user.name,
    );

    if (_ticket != null) {
      await _notifService.addNotification(
        userId: _ticket!.createdBy,
        ticketId: _ticket!.id,
        title: 'Ticket Resolved',
        body: 'Your issue has been resolved. Please confirm.',
        type: 'resolved',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resolved. Awaiting client confirmation.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  /// Option B — Request On-Site.
  /// Sends ticket to TT review queue for assignment.
  Future<void> _requestOnsite() async {
    final reason = await ActionDialog.input(
      context: context,
      title: 'Request On-Site Visit',
      hint:
      'Summary for TT: what was tried, what failed, why on-site is needed',
      confirmLabel: 'Send to TT',
      maxLines: 4,
    );
    if (reason == null) return;

    await _service.markVerified(
      widget.ticketId,
      widget.user.email,
      widget.user.name,
    );

    if (_ticket != null) {
      // Notify client
      await _notifService.addNotification(
        userId: _ticket!.createdBy,
        ticketId: _ticket!.id,
        title: 'Issue Verified',
        body:
        'We verified your issue. On-site visit will be scheduled shortly.',
        type: 'status_update',
      );

      // Notify TT
      await _notifService.addNotification(
        userId: 'tech@adsb.com',
        ticketId: _ticket!.id,
        title: 'On-Site Requested',
        body: 'Ticket ${_ticket!.id} needs on-site attention.',
        type: 'status_update',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sent to TT for on-site assignment.'),
        backgroundColor: AppColors.warning,
      ),
    );
    Navigator.pop(context);
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
    final isActive = t.status == 'pending' || t.status == 'verified';

    return Scaffold(
      appBar: AppBar(title: Text(t.id)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Client Details ───
            _card(
              title: 'Client Details',
              children: [
                _row('Name', t.createdByName),
                _row('Role',
                    t.createdByRole == 'operator' ? 'Operator' : 'Client'),
                _row('Contact', '${t.contactName} (${t.contactPhone})'),
              ],
            ),
            const SizedBox(height: 12),

            // ─── Ticket Details ───
            _card(
              title: 'Ticket Details',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Status',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ),
                    StatusBadge(status: t.status),
                  ],
                ),
                const SizedBox(height: 10),
                _row('Product', t.productType),
                _row('Issue', t.productIssue),
                _row('Site', '${t.siteName} — ${t.siteLocation}'),
                _row('Parking',
                    '${t.laneName} (${t.laneDirectionDisplay})'),
                _row('Reported', DateFormatter.full(t.createdAt)),
                if (t.description.isNotEmpty)
                  _row('Description', t.description),
              ],
            ),
            const SizedBox(height: 20),

            // ─── ACTIONS ───
            if (isActive) ...[
              _stepHeader('Step 1', 'Contact the client'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _contactBtn(
                      label: 'Call Client',
                      icon: Icons.phone_in_talk_outlined,
                      onTap: _callClient,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _contactBtn(
                      label: 'Client Chat',
                      icon: Icons.chat_bubble_outline,
                      onTap: _openClientChat,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _stepHeader('Step 2', 'Consult TT (if needed)'),
              const SizedBox(height: 6),
              const Text(
                'Client will NOT see this conversation.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _openInternalChat,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text(
                    'Internal Chat (ADSB ↔ TT)',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5E35B1),
                    side: const BorderSide(
                        color: Color(0xFF5E35B1), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _stepHeader('Step 3', 'Choose outcome'),
              const SizedBox(height: 10),

              _decisionBtn(
                label: 'Resolve Remotely',
                subtitle:
                'Issue fixed over call or chat (with or without TT advice)',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                onTap: _resolveRemotely,
              ),
              const SizedBox(height: 10),
              _decisionBtn(
                label: 'Request On-Site Visit',
                subtitle: 'Physical attendance needed. TT will assign.',
                icon: Icons.location_on_outlined,
                color: AppColors.warning,
                onTap: _requestOnsite,
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
                        'This ticket is currently ${t.statusDisplay.toLowerCase()}.',
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

  // ─── UI helpers ───

  Widget _stepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

  Widget _contactBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      height: 70,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _decisionBtn({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}