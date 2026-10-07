import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/user_service.dart';

class UserActionsSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String currentAdminEmail;
  final bool isInternalTeam;

  const UserActionsSheet({
    super.key,
    required this.userData,
    required this.currentAdminEmail,
    this.isInternalTeam = false,
  });

  @override
  State<UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends State<UserActionsSheet> {
  final _service = UserService();
  bool _isWorking = false;

  String get _uid => widget.userData['uid'] as String;
  String get _name => widget.userData['name'] ?? 'User';
  String get _email => widget.userData['email'] ?? '';
  bool get _isActive => widget.userData['is_active'] ?? true;
  String get _role => widget.userData['role'] ?? 'client';

  bool get _isSelf => _email == widget.currentAdminEmail;

  Future<void> _toggleActive() async {
    if (_isSelf) {
      _snack('You cannot deactivate your own account', AppColors.error);
      return;
    }

    // Confirm deactivation
    if (_isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Deactivate user?'),
          content: Text(
            '$_name will no longer be able to log in. '
                'Their data and history will be preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isWorking = true);

    final success = _isActive
        ? await _service.deactivateUser(_uid)
        : await _service.reactivateUser(_uid);

    if (!mounted) return;
    setState(() => _isWorking = false);

    if (success) {
      _snack(
        _isActive ? 'User deactivated' : 'User reactivated',
        AppColors.success,
      );
      Navigator.pop(context, true);
    } else {
      _snack('Action failed', AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    _name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_isActive ? AppColors.success : AppColors.error)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color:
                      _isActive ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),

          // ─── Toggle active ───
          ListTile(
            enabled: !_isWorking && !_isSelf,
            leading: Icon(
              _isActive ? Icons.block : Icons.check_circle_outline,
              color: _isSelf
                  ? AppColors.textSecondary
                  : (_isActive ? AppColors.error : AppColors.success),
            ),
            title: Text(
              _isActive ? 'Deactivate Account' : 'Reactivate Account',
              style: TextStyle(
                color: _isSelf
                    ? AppColors.textSecondary
                    : (_isActive ? AppColors.error : AppColors.success),
              ),
            ),
            subtitle: _isSelf
                ? const Text('You cannot modify your own account',
                style: TextStyle(fontSize: 11))
                : Text(
              _isActive
                  ? 'User will not be able to sign in'
                  : 'User will regain access',
              style: const TextStyle(fontSize: 11),
            ),
            onTap: _isWorking ? null : _toggleActive,
          ),

          const Divider(height: 1),

          // ─── Info tile (read-only stats) ───
          ListTile(
            leading: const Icon(Icons.info_outline,
                color: AppColors.textSecondary),
            title: const Text('Role'),
            subtitle: Text(_roleLabel(_role),
                style: const TextStyle(fontSize: 12)),
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.close, color: AppColors.textSecondary),
            title: const Text('Close'),
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'client':
        return 'Client';
      case 'operator':
        return 'Operator';
      case 'adsb':
        return 'ADSB Support Team';
      case 'technician':
        return 'Technical Advisor';
      case 'admin':
        return 'Administrator';
      default:
        return role;
    }
  }
}