import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../utils/password_validator.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'pending_approval_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _remarkController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _checkingUsername = false;
  String? _usernameError;

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _remarkController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _checkingUsername = true;
      _usernameError = null;
    });

    final available = await _authService.isUsernameAvailable(username);

    if (!mounted) return;
    setState(() {
      _checkingUsername = false;
      _usernameError =
      available ? null : 'This username is already taken';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_usernameError != null) {
      _snack(_usernameError!, AppColors.error);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      username: _usernameController.text.trim(),
      name: _nameController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      remark: _remarkController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PendingApprovalScreen(user: result.user!),
        ),
            (r) => false,
      );
    } else {
      _snack(result.message ?? 'Registration failed', AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Center(child: AppLogo(size: 64)),
                          const SizedBox(height: 16),
                          const Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your request will be reviewed by our team',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ─── Username ───
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(
                                    left: 4, bottom: 6),
                                child: Text(
                                  'Username',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _usernameController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'e.g. ahmad123',
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: AppColors.textTertiary,
                                    size: 20,
                                  ),
                                  suffixIcon: _checkingUsername
                                      ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                      : (_usernameError == null
                                      ? null
                                      : const Icon(
                                    Icons.error_outline,
                                    color: AppColors.error,
                                    size: 20,
                                  )),
                                  errorText: _usernameError,
                                ),
                                validator: (v) {
                                  if (v == null ||
                                      v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'At least 3 characters';
                                  }
                                  if (!RegExp(r'^[a-zA-Z0-9_.]+$')
                                      .hasMatch(v.trim())) {
                                    return 'Only letters, numbers, dot, underscore';
                                  }
                                  return null;
                                },
                                onChanged: (_) {
                                  if (_usernameError != null) {
                                    setState(
                                            () => _usernameError = null);
                                  }
                                },
                                onFieldSubmitted: (_) =>
                                    _checkUsername(),
                              ),
                              const SizedBox(height: 4),
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  'Lowercase letters, numbers, dot, underscore only',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          CustomTextField(
                            label: 'Full Name',
                            hint: 'e.g. Ahmad bin Abdullah',
                            icon: Icons.badge_outlined,
                            controller: _nameController,
                            validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          CustomTextField(
                            label: 'Phone Number',
                            hint: '+60 12-345 6789',
                            icon: Icons.phone_outlined,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final digits =
                              v.replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 8) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          CustomTextField(
                            label: 'Company Name / Remark',
                            hint: 'e.g. Parken Sdn Bhd',
                            icon: Icons.business_outlined,
                            controller: _remarkController,
                            validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          CustomTextField(
                            label: 'Password',
                            hint: 'Minimum 6 characters',
                            icon: Icons.lock_outline,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                              _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) =>
                                PasswordValidator.validate(v),
                          ),
                          const SizedBox(height: 14),

                          CustomTextField(
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            icon: Icons.lock_outline,
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          PrimaryButton(
                            label: 'Create Account',
                            onPressed: _isLoading ? null : _submit,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 16),

                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              child: const Text(
                                'Already have an account? Sign in',
                                style: TextStyle(
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
            );
          },
        ),
      ),
    );
  }
}