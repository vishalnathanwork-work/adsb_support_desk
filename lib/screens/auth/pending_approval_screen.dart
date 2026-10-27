import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../utils/role_router.dart';
import '../../widgets/app_logo.dart';

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
    final t = AppLocalizations.of(context)!;
    setState(() => _isChecking = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      _snack(t.pleaseLogoutLogin, AppColors.info);
      return;
    }

    final data = await UserService().getFreshUserByUid(uid);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (data == null) {
      _snack(t.accountNotFound, AppColors.error);
      return;
    }

    final isActive = data['is_active'] == true;
    final status =
    (data['approval_status'] ?? '').toString().toLowerCase();

    if (status == 'approved' && isActive) {
      final updatedUser = UserModel.fromJson({
        ...data,
        'email': data['email'] ?? widget.user.email,
      });

      if (!mounted) return;
      _snack(t.approvedWelcome, AppColors.success);
      RoleRouter.goToDashboard(context, updatedUser, replace: true);
      return;
    }

    if (status == 'rejected') {
      _snack(
        'Your registration was rejected. Contact ADSB support.',
        AppColors.error,
      );
      return;
    }

    if (status == 'approved' && !isActive) {
      _snack(
        'Your account is being activated. Please try again shortly.',
        AppColors.info,
      );
      return;
    }

    _snack(t.stillPending, AppColors.info);
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
    final t = AppLocalizations.of(context)!;
    final u = widget.user;

    return Scaffold(
      backgroundColor: Colors.transparent,   // ⭐ see global image
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                  constraints.maxHeight - (AppSpacing.xl * 2),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(AppRadii.xl),
                      boxShadow: AppShadows.large,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 64)),
                        const SizedBox(height: 20),

                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.warning
                                  .withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              size: 36,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          t.waitingForApproval,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t.waitingApprovalMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius:
                            BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.divider),
                          ),
                          child: Column(
                            children: [
                              _row(t.nameLabel, u.name),
                              _row(
                                'Username',
                                u.username.isNotEmpty
                                    ? u.username
                                    : AuthService.emailToUsername(
                                    u.email),
                              ),
                              _row(t.phoneNumber, u.phone ?? '—'),
                              if (u.remark != null &&
                                  u.remark!.isNotEmpty)
                                _row('Company (remark)', u.remark!),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      t.statusLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors
                                            .textSecondary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withOpacity(0.15),
                                      borderRadius:
                                      BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      t.statusPending,
                                      style: const TextStyle(
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

                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed:
                            _isChecking ? null : _checkStatus,
                            icon: _isChecking
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                              CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.refresh,
                                size: 18),
                            label: Text(t.refreshStatus),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        SizedBox(
                          height: 48,
                          child: TextButton.icon(
                            onPressed:
                            _isLoggingOut ? null : _logout,
                            icon: const Icon(
                              Icons.logout,
                              size: 18,
                              color: AppColors.error,
                            ),
                            label: Text(
                              t.logOut,
                              style: const TextStyle(
                                  color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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