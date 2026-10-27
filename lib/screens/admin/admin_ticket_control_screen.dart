import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
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
    final ticket = await _service.getTicketById(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _ticket = ticket;
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
        currentAssigneeEmail: _ticket!.assignedTo,
        currentAssigneeName: _ticket!.assignedToName,
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
    final t = AppLocalizations.of(context)!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.adminDeleteTicketTitle),
        content: Text(t.adminDeleteTicketMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.adminCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(t.adminDelete),
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
        SnackBar(
          content: Text(t.adminTicketDeleted),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.adminDeleteTicketFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ticket == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.ticketDetails)),
        body: Center(child: Text(t.ticketNotFound)),
      );
    }

    final ticket = _ticket!;
    final canChat =
        ticket.status != 'closed' && ticket.status != 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.id),
        backgroundColor: AppColors.primaryDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _delete,
            tooltip: t.adminDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Admin controls ───
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
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.adminControls,
                        style: const TextStyle(
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
                          label: t.adminReassign,
                          onTap: _busy ? null : _reassign,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _adminBtn(
                          icon: Icons.change_circle_outlined,
                          label: t.adminStatusBtn,
                          onTap: _busy ? null : _overrideStatus,
                        ),
                      ),
                    ],
                  ),

                  if (ticket.lastAdminAction != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                          AppColors.textPrimary.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.history,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                t.adminLastAction,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${ticket.lastAdminAction!['action']} — '
                                '${ticket.lastAdminAction!['reason'] ?? t.adminNoReason}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'by ${ticket.lastAdminAction!['by'] ?? '—'}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            _card(
              title: t.adminReportedBy,
              children: [
                _row(t.nameLabel, ticket.createdByName),
                _row(t.roleLabel, ticket.createdByRoleLabel),
                _row(t.emailLabel, ticket.createdBy),
                _row(
                  t.contactLabel,
                  '${ticket.contactName} (${ticket.contactPhone})',
                ),
              ],
            ),

            const SizedBox(height: 12),

            _card(
              title: t.ticketDetails,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.adminStatusLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    StatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 10),
                _row(t.adminProductLabel, ticket.productType),
                _row(t.adminIssueLabel, ticket.productIssue),
                _row(
                  t.adminSiteLabel,
                  '${ticket.siteName} — ${ticket.siteLocation}',
                ),
                _row(
                  t.adminLanesLabel,
                  '${ticket.laneName} (${ticket.laneDirectionDisplay})',
                ),
                _row(t.adminReportedLabel,
                    DateFormatter.full(ticket.createdAt)),
                if (ticket.description.isNotEmpty)
                  _row(t.adminDescriptionLabel, ticket.description),

                if (ticket.assignedTo != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _row(
                    t.adminAssignedTo,
                    ticket.assignedToName ?? ticket.assignedTo!,
                  ),
                  _row(t.adminAssignedEmail, ticket.assignedTo!),
                ],

                if (ticket.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    t.reportedPhotos,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: ticket.imageUrls,
                    title: t.reportedPhotos,
                  ),
                ],

                if (ticket.completionImageUrl != null &&
                    ticket.completionImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    t.completionEvidence,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: [ticket.completionImageUrl!],
                    title: t.completionEvidence,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            if (ticket.rootCause != null ||
                ticket.solutionApplied != null ||
                ticket.resolutionNotes != null) ...[
              _card(
                title: t.resolution,
                children: [
                  _row(t.rootCause, ticket.rootCause ?? '—'),
                  _row(t.solution, ticket.solutionApplied ?? '—'),
                  if (ticket.resolutionNotes != null &&
                      ticket.resolutionNotes!.isNotEmpty)
                    _row(t.notes, ticket.resolutionNotes!),
                  if (ticket.resolvedAt != null)
                    _row(t.resolvedAt,
                        DateFormatter.full(ticket.resolvedAt!)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            _card(
              title: t.adminTimelineTitle,
              children: [
                _timelineRow(t.adminReportedLabel, ticket.createdAt),
                if (ticket.adsbNotifiedAt != null)
                  _timelineRow(
                    t.adsbPending,
                    ticket.adsbNotifiedAt!,
                  ),
                if (ticket.verifiedAt != null)
                  _timelineRow(
                    t.statusVerifiedLabel,
                    ticket.verifiedAt!,
                  ),
                if (ticket.ttSolutionProvidedAt != null)
                  _timelineRow(
                    t.technicalAdvisor,
                    ticket.ttSolutionProvidedAt!,
                  ),
                if (ticket.adsbPickupAt != null)
                  _timelineRow(
                    t.statusInProgressLabel,
                    ticket.adsbPickupAt!,
                  ),
                if (ticket.workCompletedAt != null)
                  _timelineRow(
                    t.onsiteJobCompleted,
                    ticket.workCompletedAt!,
                  ),
                if (ticket.resolvedAt != null)
                  _timelineRow(t.resolved, ticket.resolvedAt!),
                if (ticket.clientConfirmedAt != null)
                  _timelineRow(
                    t.statusClosedLabel,
                    ticket.clientConfirmedAt!,
                  ),
                if (ticket.reopenedAt != null)
                  _timelineRow(
                    t.statusReopenedLabel,
                    ticket.reopenedAt!,
                  ),
              ],
            ),

            const SizedBox(height: 20),

            if (canChat)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon:
                  const Icon(Icons.chat_bubble_outline, size: 20),
                  label: Text(
                    t.adminOpenChatAsSupport,
                    style: const TextStyle(
                      fontSize: 14,
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
            width: 110,
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            DateFormatter.relative(time),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}