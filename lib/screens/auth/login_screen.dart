import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/notification_listener.dart';
import '../../utils/role_router.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/brand_background.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();
  final _session = SessionService();
  final _pushNotificationService = PushNotificationService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.success && result.user != null) {
        if (_rememberMe) {
          await _session.saveUser(result.user!);
        }

        await _pushNotificationService.initialize(result.user!.email);
        await AppNotificationListener().start(
          userEmail: result.user!.email,
          userRole: result.user!.role,
          userSiteIds: result.user!.siteIds,
        );

        if (!mounted) return;
        RoleRouter.goToDashboard(context, result.user!);
      } else {
        setState(() => _isLoading = false);
        _snack(result.message ?? 'Login failed', AppColors.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Something went wrong', AppColors.error);
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
      body: BrandBackground(
        overlayOpacity: 0.65,
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Logo + Title ───
                      const Center(child: AppLogo(size: 72)),
                      const SizedBox(height: 20),
                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ─── Email ───
                      CustomTextField(
                        label: 'Email',
                        hint: 'you@company.com',
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ─── Password ───
                      CustomTextField(
                        label: 'Password',
                        hint: 'Enter your password',
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
                          onPressed: () {
                            setState(
                                    () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 5) {
                            return 'Minimum 5 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ─── Remember me ───
                      Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primary,
                              materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (v) => setState(
                                      () => _rememberMe = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember me',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── Sign in ───
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                              : const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Version ───
                      Center(
                        child: Text(
                          'Version ${AppConstants.appVersion}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
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
  }
}