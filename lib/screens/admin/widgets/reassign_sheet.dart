import 'package:flutter/material.dart';
import '../../../config/theme.dart';
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
    if (_selectedUid == null) return;

    final user = _users.firstWhere((u) => u['uid'] == _selectedUid);

    if (user['email'] == widget.currentAssigneeEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User is already assigned to this ticket'),
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
        const SnackBar(
          content: Text('Failed to reassign'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reason for reassignment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Why is this being reassigned?',
          ),
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
      child: _loading
          ? const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          const SizedBox(height: 20),
          const Text(
            'Reassign Ticket',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a new owner. The current assignee and ticket '
                'creator will be notified.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),

          // Current assignee
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENTLY ASSIGNED TO',
                          style: TextStyle(
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
          if (_users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No assignable users found'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _users.length,
                itemBuilder: (context, i) {
                  final u = _users[i];
                  final isCurrent = u['email'] ==
                      widget.currentAssigneeEmail;
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
                          '${isCurrent ? " (current)" : ""}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    activeColor: AppColors.primary,
                    selected: _selectedUid == u['uid'],
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
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Reassign'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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