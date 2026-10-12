import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/action_dialog.dart';
import '../../widgets/image_gallery.dart';
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

  Future<void> _openChat() async {
    if (_ticket == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdsbChatScreen(
          ticketId: _ticket!.id,
          user: widget.user,
        ),
      ),
    );
    _load();
  }

  Future<void> _callTTAdvisor() async {
    const ttPhone = '+60 12-345 6792';
    final uri = Uri.parse('tel:$ttPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot call TT advisor')),
      );
    }
  }

  // ─────────────────────────────────────────
  // OUTCOMES
  // ─────────────────────────────────────────

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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resolved. Awaiting client confirmation.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _sendToOnsite() async {
    if (_ticket == null) return;

    final ok = await ActionDialog.confirm(
      context: context,
      title: 'Send to On-Site Team?',
      message:
      'The on-site queue will show this ticket as UNCLAIMED. '
          'A technician will claim and attend the site.',
      confirmLabel: 'Send to On-Site',
      confirmColor: AppColors.warning,
    );
    if (!ok) return;

    await _service.sendToOnsiteQueue(widget.ticketId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ticket sent to on-site queue.'),
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
    if (_isLoading && _ticket == null) {
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
    final isPending = t.status == 'pending';
    final isVerified = t.status == 'verified';
    final isOnsite =
        t.status == 'pending_onsite' || t.status == 'in_progress';
    final isResolved = t.status == 'resolved';
    final canChat = t.status != 'closed' && t.status != 'cancelled';

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
                _row('Role', t.createdByRoleLabel),
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
                const SizedBox(height: 10),
                _row('Product', t.productType),
                _row('Issue', t.productIssue),
                _row('Site', '${t.siteName} — ${t.siteLocation}'),
                _row('Parking',
                    '${t.laneName} (${t.laneDirectionDisplay})'),
                _row('Reported', DateFormatter.full(t.createdAt)),
                if (t.description.isNotEmpty)
                  _row('Description', t.description),

                // ── Reported Photos ──
                if (t.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Reported Photos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: t.imageUrls,
                    title: 'Reported Photos',
                  ),
                ],

                // ── Completion Evidence ──
                if (t.completionImageUrl != null &&
                    t.completionImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 14, color: AppColors.success),
                            SizedBox(width: 6),
                            Text(
                              'Completion Evidence',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ImageGallery(
                          urls: [t.completionImageUrl!],
                          title: 'Completion Evidence',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════
            // CHAT — always visible while ticket is active
            // ═══════════════════════════════════════════
            if (canChat) ...[
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 22),
                  label: const Text(
                    'Open Chat',
                    style: TextStyle(
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
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Everyone on this ticket chats here. '
                      'Client sees you as ADSB Support.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ═══════════════════════════════════════════
            // PENDING
            // ═══════════════════════════════════════════
            if (isPending) ...[
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
                ],
              ),
              const SizedBox(height: 24),
              _stepHeader('Step 2', 'Choose outcome'),
              const SizedBox(height: 10),
              _decisionBtn(
                label: 'Resolve Remotely',
                subtitle: 'Issue fixed over call or chat',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                onTap: _resolveRemotely,
              ),
              const SizedBox(height: 10),
              _decisionBtn(
                label: 'Send to On-Site Team',
                subtitle: 'Physical visit needed',
                icon: Icons.location_on_outlined,
                color: AppColors.warning,
                onTap: _sendToOnsite,
              ),
            ]

            // ═══════════════════════════════════════════
            // VERIFIED
            // ═══════════════════════════════════════════
            else if (isVerified) ...[
              const Text(
                'Waiting for review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E35B1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF5E35B1).withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top,
                        color: Color(0xFF5E35B1), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A technical advisor is reviewing this ticket. Continue the chat as needed.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _contactBtn(
                label: 'Call TT Advisor',
                icon: Icons.phone_in_talk_outlined,
                onTap: _callTTAdvisor,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'After consulting TT, choose outcome',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _decisionBtn(
                label: 'Resolve Remotely',
                subtitle: 'Issue fixed (with or without TT input)',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                onTap: _resolveRemotely,
              ),
              const SizedBox(height: 10),
              _decisionBtn(
                label: 'Send to On-Site Team',
                subtitle: 'Physical visit needed',
                icon: Icons.location_on_outlined,
                color: AppColors.warning,
                onTap: _sendToOnsite,
              ),
            ]

            // ═══════════════════════════════════════════
            // PENDING ONSITE / IN PROGRESS
            // ═══════════════════════════════════════════
            else if (isOnsite) ...[
                const Text(
                  'On-Site Work',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.status == 'pending_onsite'
                              ? 'Ticket is in the on-site queue. Waiting for a technician to claim it.'
                              : 'On-site technician is working on this ticket.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ]

              // ═══════════════════════════════════════════
              // RESOLVED
              // ═══════════════════════════════════════════
              else if (isResolved) ...[
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
                        Icon(Icons.check_circle_outline,
                            color: AppColors.success, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Issue resolved. Waiting for the client to confirm.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]

                // ═══════════════════════════════════════════
                // CLOSED / CANCELLED
                // ═══════════════════════════════════════════
                else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This ticket is ${t.statusDisplay.toLowerCase()}.',
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

  // ─────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────

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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
      height: 52,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
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
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
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