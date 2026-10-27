import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/admin_service.dart';

class ReassignSheet extends StatefulWidget {
  final String ticketId;
  final String adminEmail;
  final String? currentAssigneeEmail;
  final String? currentAssigneeName;

  const ReassignSheet({
    super.key,
    required this.ticketId,
    required this.adminEmail,
    this.currentAssigneeEmail,
    this.currentAssigneeName,
  });

  @override
  State<ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends State<ReassignSheet> {
  final _adminService = AdminService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _saving = false;
  String? _selectedUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _adminService.getAssignableUsers();
    if (!mounted) return;
    setState(() {
      _users = list;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context)!;
    if (_selectedUid == null) return;

    final user = _users.firstWhere((u) => u['uid'] == _selectedUid);

    if (user['email'] == widget.currentAssigneeEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.adminAlreadyAssigned),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final reason = await _askReason();
    if (reason == null) return;

    setState(() => _saving = true);

    final ok = await _adminService.reassign(
      ticketId: widget.ticketId,
      assigneeEmail: user['email'] as String,
      assigneeName: user['name'] as String,
      reason: reason,
      adminEmail: widget.adminEmail,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.adminReassignFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askReason() async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.adminReassignReasonTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: t.adminReassignReasonHint,
          ),
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Padding(
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
            child: _loading
                ? const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
                : SingleChildScrollView(
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
                    t.adminReassignTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.adminReassignHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  if (widget.currentAssigneeEmail != null &&
                      widget.currentAssigneeEmail!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_pin,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.adminCurrentlyAssigned,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  widget.currentAssigneeName ??
                                      widget.currentAssigneeEmail!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Inline list — no nested scroll conflict
                  if (_users.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(t.adminNoAssignable),
                    )
                  else
                    ..._users.map((u) {
                      final isCurrent =
                          u['email'] == widget.currentAssigneeEmail;
                      return RadioListTile<String>(
                        value: u['uid'] as String,
                        groupValue: _selectedUid,
                        onChanged: isCurrent
                            ? null
                            : (v) =>
                            setState(() => _selectedUid = v),
                        title: Text(
                          u['name'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: isCurrent
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${u['email']} · ${u['role']}'
                              '${isCurrent ? " " + t.adminCurrentSuffix : ""}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        activeColor: AppColors.primary,
                        selected: _selectedUid == u['uid'],
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
                          onPressed: (_selectedUid == null || _saving)
                              ? null
                              : _save,
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
                              : Text(t.adminReassignConfirm),
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