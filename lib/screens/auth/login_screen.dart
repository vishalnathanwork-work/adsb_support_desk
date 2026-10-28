import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/notification_listener.dart';
import '../../utils/role_router.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();
  final _session = SessionService();
  final _pushNotificationService = PushNotificationService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _finishLogin(AuthResult result) async {
    if (result.success && result.user != null) {
      if (_rememberMe) {
        try {
          await _session.saveUser(result.user!);
        } catch (e) {
          debugPrint('Session save error: $e');
        }
      }

      try {
        await _pushNotificationService.initialize(result.user!.email);
      } catch (e) {
        debugPrint('Push init error: $e');
      }
      try {
        await AppNotificationListener().start(
          userEmail: result.user!.email,
          userRole: result.user!.role,
          userSiteIds: result.user!.siteIds,
        );
      } catch (e) {
        debugPrint('Notification listener error: $e');
      }

      if (!mounted) return;
      RoleRouter.goToDashboard(context, result.user!);
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final t = AppLocalizations.of(context)!;
      _snack(result.message ?? t.loginFailed, AppColors.error);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.login(
        usernameOrEmail: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      await _finishLogin(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final t = AppLocalizations.of(context)!;
      _snack(t.somethingWentWrong, AppColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _showLanguagePicker() async {
    await LocaleController.instance.showLanguagePicker(context);
  }

  Future<void> _openAdminWhatsApp() async {
    final number = AppConstants.adminWhatsAppNumber;
    final message = Uri.encodeComponent(AppConstants.adminWhatsAppMessage);
    final whatsappUri = Uri.parse('https://wa.me/$number?text=$message');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _snack(
          'WhatsApp is not installed on this device.',
          AppColors.warning,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Could not open WhatsApp: $e', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final busy = _isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,

      // ⭐ LOGIN-SPECIFIC BACKGROUND
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — login background image
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

          // Layer 2 — dark overlay for readability
          Container(
            color: Colors.black.withOpacity(0.25),
          ),

          // Layer 3 — form content
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
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.65),
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
                              // ─── Language chip ───
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: _showLanguagePicker,
                                  child: Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius:
                                      BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                      border: Border.all(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.language,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          LocaleController.instance
                                              .locale
                                              .languageCode ==
                                              'ms'
                                              ? 'MS'
                                              : 'EN',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Center(child: AppLogo(size: 72)),
                              const SizedBox(height: 20),
                              Text(
                                t.appTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t.signInSubtitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 28),

                              CustomTextField(
                                label: 'Username',
                                hint: 'e.g. ahmad123',
                                icon: Icons.person_outline,
                                controller: _usernameController,
                                keyboardType: TextInputType.text,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Username is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              CustomTextField(
                                label: t.password,
                                hint: t.passwordHint,
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
                                  _obscurePassword =
                                  !_obscurePassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return t.passwordRequired;
                                  }
                                  if (v.length < 5) {
                                    return t.passwordMinLength;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: AppColors.primary,
                                      materialTapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(4),
                                      ),
                                      onChanged: (v) => setState(
                                              () => _rememberMe = v ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    t.rememberMe,
                                    style:
                                    const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: busy ? null : _handleLogin,
                                  child: _isLoading
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                      : Text(t.signIn),
                                ),
                              ),

                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    t.noAccount,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                          const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      t.createOne,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Center(
                                child: TextButton.icon(
                                  onPressed: busy
                                      ? null
                                      : _openAdminWhatsApp,
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Forgot password? Chat with admin',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                    MaterialTapTargetSize
                                        .shrinkWrap,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}