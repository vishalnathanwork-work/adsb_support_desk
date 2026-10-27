import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/admin_service.dart';

class StatusOverrideSheet extends StatefulWidget {
  final String ticketId;
  final String currentStatus;
  final String adminEmail;

  const StatusOverrideSheet({
    super.key,
    required this.ticketId,
    required this.currentStatus,
    required this.adminEmail,
  });

  @override
  State<StatusOverrideSheet> createState() => _StatusOverrideSheetState();
}

class _StatusOverrideSheetState extends State<StatusOverrideSheet> {
  final _adminService = AdminService();
  String? _selected;
  bool _saving = false;

  Future<void> _save() async {
    if (_selected == null) return;

    final isReopening =
        (widget.currentStatus == 'closed' ||
            widget.currentStatus == 'cancelled') &&
            _selected != 'cancelled';

    final reason = await _askReason(isReopening: isReopening);
    if (reason == null) return;

    setState(() => _saving = true);

    final ok = await _adminService.overrideStatus(
      ticketId: widget.ticketId,
      newStatus: _selected!,
      reason: reason,
      adminEmail: widget.adminEmail,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.adminOverrideFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askReason({required bool isReopening}) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isReopening
              ? t.adminOverrideReopenTitle
              : t.adminOverrideReasonTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReopening)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.adminOverrideReopenWarn,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: t.adminOverrideReasonHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.adminCancel),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: Text(t.confirmLabel),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'pending':
        return t.statusPendingLabel;
      case 'verified':
        return t.statusVerifiedLabel;
      case 'pending_onsite':
        return t.statusPendingOnsiteLabel;
      case 'in_progress':
        return t.statusInProgressLabel;
      case 'resolved':
        return t.statusResolvedLabel;
      case 'closed':
        return t.statusClosedLabel;
      case 'reopened':
        return t.statusReopenedLabel;
      case 'cancelled':
        return t.statusCancelledLabel;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    const statusKeys = [
      'pending',
      'verified',
      'pending_onsite',
      'in_progress',
      'resolved',
      'closed',
      'reopened',
      'cancelled',
    ];

    return Padding(
      // Keyboard-aware: pushes the sheet up instead of growing inner padding
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                  Text(
                    t.adminOverrideTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.adminOverrideCurrent(
                      _statusLabel(t, widget.currentStatus),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Inline list — no nested scroll conflict
                  ...statusKeys.map((key) {
                    final isCurrent = key == widget.currentStatus;
                    final selected = _selected == key;
                    return RadioListTile<String>(
                      value: key,
                      groupValue: _selected,
                      onChanged: isCurrent
                          ? null
                          : (v) => setState(() => _selected = v),
                      title: Text(
                        _statusLabel(t, key),
                        style: TextStyle(
                          fontSize: 14,
                          color: isCurrent
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: isCurrent
                          ? Text(
                        t.adminCurrentSuffix,
                        style: const TextStyle(fontSize: 11),
                      )
                          : null,
                      activeColor: AppColors.primary,
                      selected: selected,
                    );
                  }),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(t.adminCancel),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                          (_selected == null || _saving) ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _saving
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(t.adminApplyOverride),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}