import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/status_badge.dart';
import '../adsb/adsb_chat_screen.dart';
import 'widgets/reassign_sheet.dart';
import 'widgets/status_override_sheet.dart';

/// Admin-only full-power view of a ticket.
/// Admins can chat, reassign, override status, and delete.
class AdminTicketControlScreen extends StatefulWidget {
  final String ticketId;
  final UserModel admin;

  const AdminTicketControlScreen({
    super.key,
    required this.ticketId,
    required this.admin,
  });

  @override
  State<AdminTicketControlScreen> createState() =>
      _AdminTicketControlScreenState();
}

class _AdminTicketControlScreenState
    extends State<AdminTicketControlScreen> {
  final _service = TicketService();
  final _adminService = AdminService();
  Ticket? _ticket;
  bool _isLoading = true;
  bool _busy = false;

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
          user: widget.admin,
        ),
      ),
    );
    _load();
  }

  Future<void> _reassign() async {
    if (_ticket == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReassignSheet(
        ticketId: _ticket!.id,
        adminEmail: widget.admin.email,
      ),
    );

    if (changed == true) _load();
  }

  Future<void> _overrideStatus() async {
    if (_ticket == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatusOverrideSheet(
        ticketId: _ticket!.id,
        currentStatus: _ticket!.status,
        adminEmail: widget.admin.email,
      ),
    );

    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this ticket?'),
        content: const Text(
            'This will permanently remove the ticket and all chat messages. '
                'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),  // ✅
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    final success = await _adminService.deleteTicket(widget.ticketId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket deleted'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete ticket'),
          backgroundColor: AppColors.error,
        ),
      );
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
    final canChat = t.status != 'closed' && t.status != 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: Text(t.id),
        backgroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _delete,
            tooltip: 'Delete ticket',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Admin controls card ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textPrimary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          size: 16, color: AppColors.textPrimary),
                      SizedBox(width: 6),
                      Text(
                        'ADMIN CONTROLS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _adminBtn(
                          icon: Icons.swap_horiz,
                          label: 'Reassign',
                          onTap: _busy ? null : _reassign,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _adminBtn(
                          icon: Icons.change_circle_outlined,
                          label: 'Status',
                          onTap: _busy ? null : _overrideStatus,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Reported by ───
            _card(
              title: 'Reported By',
              children: [
                _row('Name', t.createdByName),
                _row('Role', t.createdByRoleLabel),
                _row('Email', t.createdBy),
                _row('Contact', '${t.contactName} (${t.contactPhone})'),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Ticket details ───
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

                // ─── Assignment ───
                if (t.assignedTo != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _row('Assigned To', t.assignedToName ?? t.assignedTo!),
                  _row('Assigned Email', t.assignedTo!),
                ],

                // ─── Reported Photos ───
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

                // ─── Completion Evidence ───
                if (t.completionImageUrl != null &&
                    t.completionImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Completion Evidence',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: [t.completionImageUrl!],
                    title: 'Completion Evidence',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ─── Resolution ───
            if (t.rootCause != null ||
                t.solutionApplied != null ||
                t.resolutionNotes != null) ...[
              _card(
                title: 'Resolution',
                children: [
                  _row('Root Cause', t.rootCause ?? '—'),
                  _row('Solution', t.solutionApplied ?? '—'),
                  if (t.resolutionNotes != null &&
                      t.resolutionNotes!.isNotEmpty)
                    _row('Notes', t.resolutionNotes!),
                  if (t.resolvedAt != null)
                    _row('Resolved At', DateFormatter.full(t.resolvedAt!)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ─── Timeline ───
            _card(
              title: 'Timeline',
              children: [
                _timelineRow('Created', t.createdAt),
                if (t.adsbNotifiedAt != null)
                  _timelineRow('ADSB notified', t.adsbNotifiedAt!),
                if (t.verifiedAt != null)
                  _timelineRow('Verified / escalated', t.verifiedAt!),
                if (t.ttSolutionProvidedAt != null)
                  _timelineRow('TT advice provided', t.ttSolutionProvidedAt!),
                if (t.adsbPickupAt != null)
                  _timelineRow('On-site picked up', t.adsbPickupAt!),
                if (t.workCompletedAt != null)
                  _timelineRow('Work completed', t.workCompletedAt!),
                if (t.resolvedAt != null)
                  _timelineRow('Resolved', t.resolvedAt!),
                if (t.clientConfirmedAt != null)
                  _timelineRow('Client confirmed', t.clientConfirmedAt!),
                if (t.reopenedAt != null)
                  _timelineRow('Reopened', t.reopenedAt!),
              ],
            ),

            const SizedBox(height: 20),

            // ─── Chat ───
            if (canChat)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text(
                    'Open Chat (post as ADSB Support)',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
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
          ],
        ),
      ),
    );
  }

  Widget _adminBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.textPrimary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
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
            width: 110,
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

  Widget _timelineRow(String label, DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12)),
          ),
          Text(
            DateFormatter.relative(time),
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}