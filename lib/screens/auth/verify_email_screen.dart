import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        return;
      }

      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (refreshed?.emailVerified != true) {
        setState(() => _isChecking = false);
        _snack(
          'Email not yet verified. Check your inbox and click the link.',
          AppColors.warning,
        );
        return;
      }

      // ⭐ Server-side sync — writes is_verified: true
      final result = await _authService.syncVerifiedEmail();

      if (!mounted) return;
      setState(() => _isChecking = false);

      if (result.success) {
        _snack(
          'Email verified! Admin will review your account shortly.',
          AppColors.success,
        );
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      } else {
        _snack(
          result.message ?? 'Failed to confirm verification.',
          AppColors.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      _snack('Error checking verification: $e', AppColors.error);
    }
  }

  Future<void> _resendEmail() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      _snack('Session expired. Please log in again.', AppColors.error);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      return;
    }

    setState(() => _isResending = true);

    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() => _isResending = false);
      _snack(
        'Verification email sent again. Check your inbox.',
        AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _snack('Failed to resend: $e', AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_register_background.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A5568), Color(0xFF2F3643)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.45)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: AppShadows.large,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AppLogo(size: 64)),
                          const SizedBox(height: 24),
                          const Center(
                            child: Icon(
                              Icons.mark_email_unread_outlined,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Verify Your Email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'We sent a verification link to:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius:
                              BorderRadius.circular(AppRadii.md),
                              border:
                              Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              widget.email,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Click the link in the email, then return here '
                                'and tap "I\'ve Verified".\n\n'
                                'Admins review your account only after your '
                                'email is confirmed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed:
                              _isChecking ? null : _checkVerified,
                              icon: _isChecking
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2),
                              )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                _isChecking
                                    ? 'Checking...'
                                    : 'I\'ve Verified My Email',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed:
                              _isResending ? null : _resendEmail,
                              icon: _isResending
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                                  : const Icon(Icons.refresh, size: 18),
                              label: Text(
                                _isResending
                                    ? 'Sending...'
                                    : 'Resend Verification Email',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                    '/login', (r) => false);
                              },
                              child: const Text(
                                'Back to Login',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ),
        ],
      ),
    );
  }
}