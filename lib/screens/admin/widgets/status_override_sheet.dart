import 'package:flutter/material.dart';
import '../../../config/theme.dart';
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

  static const _statuses = [
    {'key': 'pending', 'label': 'Pending Verification'},
    {'key': 'verified', 'label': 'Verified (with TT)'},
    {'key': 'pending_onsite', 'label': 'Pending On-Site'},
    {'key': 'in_progress', 'label': 'On-Site In Progress'},
    {'key': 'resolved', 'label': 'Resolved'},
    {'key': 'closed', 'label': 'Closed'},
    {'key': 'reopened', 'label': 'Reopened'},
    {'key': 'cancelled', 'label': 'Cancelled'},
  ];

  Future<void> _save() async {
    if (_selected == null) return;

    // Warn if jumping from a closed state
    final isReopening =
        (widget.currentStatus == 'closed' || widget.currentStatus == 'cancelled') &&
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to override status'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askReason({required bool isReopening}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isReopening
            ? 'Reopen a closed ticket?'
            : 'Reason for override'),
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
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: AppColors.warning, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You are reopening a closed ticket. '
                            'The client will be notified.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Why is the status being changed manually?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          const SizedBox(height: 20),
          const Text(
            'Override Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Current: ${_statusLabel(widget.currentStatus)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _statuses.length,
              itemBuilder: (context, i) {
                final s = _statuses[i];
                final key = s['key']!;
                final isCurrent = key == widget.currentStatus;
                final selected = _selected == key;
                return RadioListTile<String>(
                  value: key,
                  groupValue: _selected,
                  onChanged: isCurrent
                      ? null
                      : (v) => setState(() => _selected = v),
                  title: Text(
                    s['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrent
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: isCurrent
                      ? const Text('(current)',
                      style: TextStyle(fontSize: 11))
                      : null,
                  activeColor: AppColors.primary,
                  selected: selected,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
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
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Apply Override'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'pending_onsite':
        return 'On-Site Queued';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'reopened':
        return 'Reopened';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}