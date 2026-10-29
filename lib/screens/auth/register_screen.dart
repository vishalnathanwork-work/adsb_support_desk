import 'dart:ui';

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../utils/password_validator.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _remarkController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _remarkController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _authService.registerWithEmail(
      email: _emailController.text.trim().toLowerCase(),
      name: _nameController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      remark: _remarkController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      // ⭐ Route to VerifyEmailScreen (not PendingApprovalScreen)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: _emailController.text.trim().toLowerCase(),
          ),
        ),
            (r) => false,
      );
    } else {
      _snack(result.message ?? t.registrationFailed, AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final busy = _isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.88),
                              borderRadius:
                              BorderRadius.circular(AppRadii.xl),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.5,
                              ),
                              boxShadow: AppShadows.large,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Center(
                                      child: AppLogo(size: 64)),
                                  const SizedBox(height: 16),
                                  Text(
                                    t.createAccount,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t.createAccountSubtitle,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  CustomTextField(
                                    label: t.emailLabel,
                                    hint: t.emailHintRegister,
                                    icon: Icons.email_outlined,
                                    controller: _emailController,
                                    keyboardType:
                                    TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null ||
                                          v.trim().isEmpty) {
                                        return t.required;
                                      }
                                      if (!RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch(v.trim())) {
                                        return t.invalidEmail;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  CustomTextField(
                                    label: t.fullName,
                                    hint: t.fullNameHint,
                                    icon: Icons.badge_outlined,
                                    controller: _nameController,
                                    validator: (v) => v == null ||
                                        v.trim().isEmpty
                                        ? t.required
                                        : null,
                                  ),
                                  const SizedBox(height: 14),

                                  CustomTextField(
                                    label: t.phoneNumber,
                                    hint: t.phoneHint,
                                    icon: Icons.phone_outlined,
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    validator: (v) {
                                      if (v == null ||
                                          v.trim().isEmpty) {
                                        return t.required;
                                      }
                                      final digits =
                                      v.replaceAll(RegExp(r'\D'), '');
                                      if (digits.length < 8) {
                                        return t.phoneInvalid;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  CustomTextField(
                                    label: t.company,
                                    hint: t.clientNameHint,
                                    icon: Icons.business_outlined,
                                    controller: _remarkController,
                                    validator: (v) => v == null ||
                                        v.trim().isEmpty
                                        ? t.required
                                        : null,
                                  ),
                                  const SizedBox(height: 14),

                                  CustomTextField(
                                    label: t.passwordLabel,
                                    hint: t.passwordHintRegister,
                                    icon: Icons.lock_outline,
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons
                                            .visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                      _obscurePassword =
                                      !_obscurePassword),
                                    ),
                                    validator: (v) =>
                                        PasswordValidator.validate(v),
                                  ),
                                  const SizedBox(height: 14),

                                  CustomTextField(
                                    label: t.confirmPasswordLabel,
                                    hint: t.confirmPasswordHint,
                                    icon: Icons.lock_outline,
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirm,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons
                                            .visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                      _obscureConfirm =
                                      !_obscureConfirm),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return t.pleaseConfirmPassword;
                                      }
                                      if (v != _passwordController.text) {
                                        return t.passwordsDoNotMatch;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  PrimaryButton(
                                    label: t.createAccount,
                                    onPressed: busy ? null : _submit,
                                    isLoading: _isLoading,
                                  ),
                                  const SizedBox(height: 16),

                                  Center(
                                    child: TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => Navigator.pop(context),
                                      child: Text(
                                        t.alreadyHaveAccount,
                                        style: const TextStyle(
                                          color: AppColors.primary,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}