import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/auth_service.dart';
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
  final _authService = AuthService();
  bool _isWorking = false;

  String get _uid => widget.userData['uid'] as String;
  String get _name => widget.userData['name'] ?? 'User';
  String get _email => widget.userData['email'] ?? '';
  String get _username => (widget.userData['username'] ?? '').toString();
  bool get _isActive => widget.userData['is_active'] ?? true;
  String get _role => widget.userData['role'] ?? 'owner';

  bool get _isSelf => _email == widget.currentAdminEmail;

  // ═══════════════════════════════════════════════
  // TOGGLE ACTIVE
  // ═══════════════════════════════════════════════

  Future<void> _toggleActive() async {
    final t = AppLocalizations.of(context)!;

    if (_isSelf) {
      _snack(t.adminSelfDeactivateBlocked, AppColors.error);
      return;
    }

    if (_isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t.adminDeactivateTitle),
          content: Text(t.adminDeactivateMessage(_name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t.adminCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(t.adminDeactivate),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (!mounted) return;
    setState(() => _isWorking = true);

    final success = _isActive
        ? await _service.deactivateUser(_uid)
        : await _service.reactivateUser(_uid);

    if (!mounted) return;
    setState(() => _isWorking = false);

    if (success) {
      _snack(
        _isActive ? t.adminUserDeactivated : t.adminUserReactivated,
        AppColors.success,
      );
      Navigator.pop(context, true);
    } else {
      _snack(t.adminActionFailed, AppColors.error);
    }
  }

  // ═══════════════════════════════════════════════
  // RESET PASSWORD
  // ═══════════════════════════════════════════════

  Future<void> _showResetPasswordDialog() async {
    String newPassword = '';
    bool obscure = true;
    bool isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              setDialogState(() => errorText = null);

              if (newPassword.length < 6) {
                setDialogState(
                        () => errorText = 'Minimum 6 characters required');
                return;
              }

              setDialogState(() => isSubmitting = true);

              final result = await _authService.adminResetPassword(
                targetUid: _uid,
                newPassword: newPassword,
              );

              if (!context.mounted) return;

              setDialogState(() => isSubmitting = false);

              if (!result.success) {
                setDialogState(
                        () => errorText = result.message ?? 'Reset failed');
                return;
              }

              Navigator.pop(dialogContext);

              if (!mounted) return;
              await _showPasswordResultDialog(newPassword);
            }

            return AlertDialog(
              title: Text('Reset Password for $_name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set a new password. Call the user and give it to them.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    obscureText: obscure,
                    onChanged: (v) {
                      newPassword = v;
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Minimum 6 characters',
                      errorText: errorText,
                      prefixIcon:
                      const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Reset Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPasswordResultDialog(String newPassword) async {
    await showDialog<void>(
      context: context,
      builder: (resultContext) => AlertDialog(
        title: const Text('Password Reset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New password for $_name:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: SelectableText(
                newPassword,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Call the user and give them this password. '
                  'They can change it later from their Profile.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(resultContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ═══════════════════════════════════════════════
  // DELETE USER
  // ═══════════════════════════════════════════════

  Future<void> _deleteUser() async {
    final t = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.adminDeleteUserTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.adminDeleteUserMessage(_name),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.adminDeleteUserWarning,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.adminCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(t.adminDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isWorking = true);
    final success = await _service.deleteUser(_uid);
    if (!mounted) return;
    setState(() => _isWorking = false);

    if (success) {
      _snack(t.adminUserDeleted, AppColors.warning);
      Navigator.pop(context, true);
    } else {
      _snack(t.adminDeleteFailed, AppColors.error);
    }
  }

  // ═══════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _roleLabel(AppLocalizations t, String role) {
    switch (role) {
      case 'owner':
        return t.siteOwner;
      case 'operator':
        return t.siteOperator;
      case 'adsb':
        return t.supportTeam;
      case 'technician':
        return t.technicalAdvisor;
      case 'onsite':
        return t.onSiteTechnician;
      case 'admin':
        return t.administrator;
      default:
        return role;
    }
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final displayUsername =
    _username.isNotEmpty ? _username : _email.split('@').first;

    return Padding(
      // Keyboard-aware: push sheet up instead of growing inner padding
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
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                          AppColors.primary.withOpacity(0.15),
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
                          'Username: $displayUsername',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (_isActive
                                ? AppColors.success
                                : AppColors.error)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isActive
                                ? t.adminActiveBadge
                                : t.adminInactiveBadge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _isActive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),

                  ListTile(
                    enabled: !_isWorking,
                    leading: const Icon(
                      Icons.lock_reset,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Reset Password',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    subtitle: const Text(
                      'Set a new password and tell the user by phone',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: _isWorking ? null : _showResetPasswordDialog,
                  ),

                  const Divider(height: 1),

                  ListTile(
                    enabled: !_isWorking && !_isSelf,
                    leading: Icon(
                      _isActive ? Icons.block : Icons.check_circle_outline,
                      color: _isSelf
                          ? AppColors.textSecondary
                          : (_isActive
                          ? AppColors.error
                          : AppColors.success),
                    ),
                    title: Text(
                      _isActive ? t.adminDeactivateBtn : t.adminReactivate,
                      style: TextStyle(
                        color: _isSelf
                            ? AppColors.textSecondary
                            : (_isActive
                            ? AppColors.error
                            : AppColors.success),
                      ),
                    ),
                    subtitle: _isSelf
                        ? Text(
                      t.adminSelfEditBlocked,
                      style: const TextStyle(fontSize: 11),
                    )
                        : Text(
                      _isActive
                          ? t.adminWillNotSignIn
                          : t.adminWillRegainAccess,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: _isWorking ? null : _toggleActive,
                  ),

                  const Divider(height: 1),

                  ListTile(
                    enabled: !_isWorking && !_isSelf,
                    leading: Icon(
                      Icons.delete_forever,
                      color: _isSelf
                          ? AppColors.textSecondary
                          : AppColors.error,
                    ),
                    title: Text(
                      t.adminDeleteBtn,
                      style: TextStyle(
                        color: _isSelf
                            ? AppColors.textSecondary
                            : AppColors.error,
                      ),
                    ),
                    subtitle: Text(
                      _isSelf
                          ? t.adminSelfDeleteBlocked
                          : t.adminDeleteFirestoreOnly,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: _isWorking || _isSelf ? null : _deleteUser,
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(t.adminRoleLabel),
                    subtitle: Text(
                      _roleLabel(t, _role),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(t.closeLabel),
                    onTap: () => Navigator.pop(context, false),
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