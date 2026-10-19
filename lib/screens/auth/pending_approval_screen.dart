import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../utils/role_router.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/brand_background.dart';

class PendingApprovalScreen extends StatefulWidget {
  final UserModel user;

  const PendingApprovalScreen({super.key, required this.user});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isChecking = false;
  bool _isLoggingOut = false;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      _snack('Please log out and log back in.', AppColors.info);
      return;
    }

    final data = await UserService().getFreshUserByUid(uid);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (data == null) {
      _snack('Account not found. Contact admin.', AppColors.error);
      return;
    }

    final isActive = data['is_active'] == true;
    final status = data['approval_status'] ?? 'pending';

    if (isActive && status == 'approved') {
      final updatedUser = UserModel.fromJson({
        ...data,
        'email': data['email'] ?? widget.user.email,
      });

      if (!mounted) return;
      _snack('Approved! Welcome aboard.', AppColors.success);
      RoleRouter.goToDashboard(context, updatedUser, replace: true);
    } else {
      _snack(
        'Still pending. Please wait for admin approval.',
        AppColors.info,
      );
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    await SessionService().clear();
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return Scaffold(
      body: BrandBackground(
        overlayOpacity: 0.55,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: AppShadows.large,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 64)),
                    const SizedBox(height: 20),

                    // Status icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 36,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Waiting for Approval',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your registration has been submitted. '
                          'An ADSB administrator will review and approve '
                          'your account shortly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status summary card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          _row('Name', u.name),
                          _row('Email', u.email),
                          _row('Role', u.roleDisplayName),
                          if (u.clientName != null)
                            _row('Client', u.clientName!),
                          _row(
                            'Sites',
                            u.siteIds.length == 1
                                ? '1 site'
                                : '${u.siteIds.length} sites',
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 90,
                                child: Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PENDING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isChecking ? null : _checkStatus,
                        icon: _isChecking
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh Status'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: TextButton.icon(
                        onPressed: _isLoggingOut ? null : _logout,
                        icon: const Icon(Icons.logout,
                            size: 18, color: AppColors.error),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                fontSize: 12,
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
}
