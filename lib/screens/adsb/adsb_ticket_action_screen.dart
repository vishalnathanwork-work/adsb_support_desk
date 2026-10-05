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

  Future<void> _assignToMe() async {
    await _service.assignToMe(
      widget.ticketId,
      widget.user.email,
      widget.user.name,
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ticket assigned to you'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _resolveRemotely() async {
    final ok = await ActionDialog.confirm(
      context: context,
      title: 'Resolve Remotely?',
      message:
      'This will close the ticket as resolved via chat/call. The client will be notified.',
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
        body: 'Your issue was resolved remotely. Please confirm.',
        type: 'resolved',
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _escalateToTT() async {
    final reason = await ActionDialog.input(
      context: context,
      title: 'Escalate to TT',
      hint: 'Describe what was verified and why on-site attention is needed',
      confirmLabel: 'Escalate',
      maxLines: 4,
    );
    if (reason == null) return;

    await _service.markVerified(
      widget.ticketId,
      widget.user.email,
      widget.user.name,
    );

    if (_ticket != null) {
      await _notifService.addNotification(
        userId: _ticket!.createdBy,
        ticketId: _ticket!.id,
        title: 'Issue Verified',
        body: 'Our team verified your issue. We will attend shortly.',
        type: 'status_update',
      );
      // Notify TT team
      await _notifService.addNotification(
        userId: 'tech@adsb.com',
        ticketId: _ticket!.id,
        title: 'New Escalation',
        body: 'Ticket ${_ticket!.id} requires technical review.',
        type: 'status_update',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Escalated to TT team'),
        backgroundColor: AppColors.accent,
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
            // Client info
            _card(
              title: 'Client Details',
              children: [
                _row('Name', t.createdByName),
                _row('Role', t.createdByRole == 'operator' ? 'Operator' : 'Client'),
                _row('Contact', '${t.contactName} (${t.contactPhone})'),
              ],
            ),
            const SizedBox(height: 12),

            // Ticket info
            _card(
              title: 'Ticket Details',
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
                _row('Product', t.productType),
                _row('Issue', t.productIssue),
                _row('Site', '${t.siteName} — ${t.siteLocation}'),
                _row('Reported', DateFormatter.full(t.createdAt)),
                if (t.description.isNotEmpty) _row('Description', t.description),
              ],
            ),
            const SizedBox(height: 20),

            // Action buttons
            if (t.status == 'pending') ...[
              if (t.assignedTo == null)
                _primaryBtn(
                  label: 'Assign to Me',
                  icon: Icons.person_add_outlined,
                  onTap: _assignToMe,
                  color: AppColors.accent,
                )
              else
                _primaryBtn(
                  label: 'Contact Client',
                  icon: Icons.phone,
                  onTap: _callClient,
                  color: AppColors.primary,
                ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _actionBtn(
                      label: 'Call Client',
                      icon: Icons.phone_in_talk_outlined,
                      onTap: _callClient,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionBtn(
                      label: 'Chat',
                      icon: Icons.chat_bubble_outline,
                      onTap: () {
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
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Decision
              const Text(
                'After verification, choose:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              _decisionBtn(
                label: 'Resolve Remotely',
                subtitle: 'Issue can be fixed over call/chat',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                onTap: _resolveRemotely,
              ),
              const SizedBox(height: 10),
              _decisionBtn(
                label: 'Escalate to TT',
                subtitle: 'Needs Technical Advisor review',
                icon: Icons.arrow_upward,
                color: AppColors.warning,
                onTap: _escalateToTT,
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
                        'This ticket has already been ${t.statusDisplay.toLowerCase()}.',
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

  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
                          fontSize: 12, color: AppColors.textSecondary)),
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