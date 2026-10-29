import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'config/routes.dart';
import 'config/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'models/user_model.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/operator/operator_dashboard.dart';
import 'screens/adsb/adsb_dashboard.dart';
import 'screens/technician/technician_dashboard.dart';
import 'screens/onsite/onsite_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'services/session_service.dart';
import 'services/session_guard_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AdsbSupportApp extends StatefulWidget {
  const AdsbSupportApp({super.key});

  @override
  State<AdsbSupportApp> createState() => _AdsbSupportAppState();
}

class _AdsbSupportAppState extends State<AdsbSupportApp> {
  @override
  void initState() {
    super.initState();
    LocaleController.instance.load();

    SessionGuardService().onSessionInvalidated = _handleSessionInvalidated;
  }

  Future<void> _handleSessionInvalidated() async {
    // Clear local session storage
    await SessionService().clear();

    // Show a dialog and route to login
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Wait for any pending navigation to settle
    await Future.delayed(const Duration(milliseconds: 100));

    // Show a dialog on top of whatever is showing
    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Session Ended'),
        content: const Text(
          'Your account was signed in on another device. '
              'You have been logged out here.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(nav.context).pop();
              nav.pushNamedAndRemoveUntil('/login', (r) => false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,

          // ⭐ Framework fallback color — prevents white flash
          color: Colors.white,

          // ⭐ Don't animate theme transitions (avoids flicker)
          themeAnimationDuration: Duration.zero,
          themeAnimationCurve: Curves.linear,

          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
          },
          locale: LocaleController.instance.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          // ⭐⭐⭐ GLOBAL BACKGROUND — applies to EVERY screen ⭐⭐⭐
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Solid fallback color — painted first, so even a
                //    1-frame image load gap shows the tinted color
                //    instead of stark white.
                Container(
                  color: const Color(0xFFF6F8FB),
                ),

                // 2. Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/new_background.jpg',
                    fit: BoxFit.cover,
                    gaplessPlayback: true,   // ⭐ no flicker on rebuild
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

                // 3. Semi-transparent white veil
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),

                // 4. The actual app content
                child ?? const SizedBox.shrink(),
              ],
            );
          },

          onGenerateRoute: (settings) {
            final user = settings.arguments as UserModel?;

            switch (settings.name) {
              case AppRoutes.ownerDashboard:
                if (user == null) return _fallbackLogin();
                return MaterialPageRoute(
                  builder: (_) => OwnerDashboard(user: user),
                );
              case AppRoutes.operatorDashboard:
                if (user == null) return _fallbackLogin();
                return MaterialPageRoute(
                  builder: (_) => OperatorDashboard(user: user),
                );
              case AppRoutes.adsbDashboard:
                if (user == null) return _fallbackLogin();
                return MaterialPageRoute(
                  builder: (_) => AdsbDashboard(user: user),
                );
              case AppRoutes.technicianDashboard:
                if (user == null) return _fallbackLogin();
                return MaterialPageRoute(
                  builder: (_) => TechnicianDashboard(user: user),
                );
              case AppRoutes.onsiteDashboard:
                if (user == null) return _fallbackLogin();
                return MaterialPageRoute(
                  builder: (_) => OnsiteDashboard(user: user),
                );
              case AppRoutes.adminDashboard:
                if (user == null) return _fallbackLogin();
                return MaterialPageRoute(
                  builder: (_) => AdminDashboard(user: user),
                );
              default:
                return _fallbackLogin();
            }
          },
        );
      },
    );
  }

  static MaterialPageRoute _fallbackLogin() =>
      MaterialPageRoute(builder: (_) => const LoginScreen());
}