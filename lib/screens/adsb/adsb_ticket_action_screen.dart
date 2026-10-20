import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
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
  Ticket? _ticket;
  bool _isLoading = true;
  bool _isWorking = false;

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

  // ═══════════════════════════════════════════════
  // CALL ACTIONS
  // ═══════════════════════════════════════════════

  Future<void> _callClient() async {
    if (_ticket == null) return;
    final phone =
    _ticket!.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      _snack('Cannot call $phone', AppColors.error);
    }
  }

  // ═══════════════════════════════════════════════
  // OPEN CHAT
  // ═══════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════
  // OUTCOME ACTIONS
  // ═══════════════════════════════════════════════

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

    setState(() => _isWorking = true);
    await _service.resolveRemotely(
      widget.ticketId,
      widget.user.email,
      widget.user.name,
    );
    if (!mounted) return;
    setState(() => _isWorking = false);

    _snack('Resolved. Awaiting client confirmation.', AppColors.success);
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

    setState(() => _isWorking = true);
    await _service.sendToOnsiteQueue(widget.ticketId);
    if (!mounted) return;
    setState(() => _isWorking = false);

    _snack('Ticket sent to on-site queue.', AppColors.warning);
    Navigator.pop(context);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ═══════════════════════════════════════════════
  // STATE HELPERS
  // ═══════════════════════════════════════════════

  bool get _isClosedOrCancelled =>
      _ticket == null ||
          _ticket!.status == 'closed' ||
          _ticket!.status == 'cancelled';

  bool get _canResolveRemotely {
    if (_ticket == null) return false;
    return _ticket!.status == 'pending' ||
        _ticket!.status == 'verified' ||
        _ticket!.status == 'in_progress';
  }

  bool get _canSendToOnsite {
    if (_ticket == null) return false;
    return _ticket!.status == 'pending' ||
        _ticket!.status == 'verified';
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

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

    return Scaffold(
      appBar: AppBar(title: Text(t.id)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ═══════════════════════════════════════════
            // CLIENT DETAILS
            // ═══════════════════════════════════════════
            _sectionHeader('Client Details'),
            _card(
              children: [
                _row('Name', t.createdByName),
                _row('Role', t.createdByRoleLabel),
                _row('Contact', '${t.contactName} · ${t.contactPhone}'),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ═══════════════════════════════════════════
            // TICKET DETAILS
            // ═══════════════════════════════════════════
            _sectionHeader('Ticket Details'),
            _card(
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
                if (t.productIssue.isNotEmpty)
                  _row('Issue', t.productIssue),
                _row('Site', '${t.siteName} — ${t.siteLocation}'),
                _row('Lanes', t.lanesSummary),
                _row('Reported', DateFormatter.full(t.createdAt)),
                if (t.description.isNotEmpty)
                  _row('Description', t.description),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ═══════════════════════════════════════════
            // CONTACT
            // ═══════════════════════════════════════════
            _sectionHeader('Contact'),

            // Open Chat — full width
            _primaryActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'Open Chat',
              color: AppColors.accent,
              onTap: !_isClosedOrCancelled && !_isWorking
                  ? _openChat
                  : null,
            ),

            const SizedBox(height: AppSpacing.md),

            // Call Client — full width
            _primaryActionButton(
              icon: Icons.phone_in_talk_outlined,
              label: 'Call Client',
              color: AppColors.primary,
              onTap: !_isClosedOrCancelled && !_isWorking
                  ? _callClient
                  : null,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════
            // OUTCOME
            // ═══════════════════════════════════════════
            _sectionHeader('Outcome'),

            _outcomeButton(
              icon: Icons.check_circle_outline,
              label: 'Resolve Remotely',
              subtitle: _canResolveRemotely
                  ? 'Issue fixed over call or chat'
                  : 'Not available for current status',
              color: AppColors.success,
              onTap: _canResolveRemotely && !_isWorking
                  ? _resolveRemotely
                  : null,
            ),

            const SizedBox(height: AppSpacing.md),

            _outcomeButton(
              icon: Icons.location_on_outlined,
              label: 'Send to On-Site Team',
              subtitle: _canSendToOnsite
                  ? 'Physical visit required'
                  : 'Not available for current status',
              color: AppColors.warning,
              onTap: _canSendToOnsite && !_isWorking
                  ? _sendToOnsite
                  : null,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // UI HELPERS
  // ═══════════════════════════════════════════════

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
        left: 4,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textTertiary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    );
  }

  Widget _outcomeButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: enabled ? color : AppColors.divider,
            width: enabled ? 2 : 1,
          ),
          boxShadow: enabled ? AppShadows.soft : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled
                    ? color.withOpacity(0.12)
                    : AppColors.divider.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(
                icon,
                color: enabled ? color : AppColors.textTertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: enabled ? color : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}