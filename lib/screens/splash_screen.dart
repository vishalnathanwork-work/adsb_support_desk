import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/session_service.dart';
import '../services/push_notification_service.dart';
import '../services/notification_listener.dart';
import '../utils/role_router.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _session = SessionService();
  final _push = PushNotificationService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Give the splash a moment to render
    await Future.delayed(const Duration(milliseconds: 800));

    final user = await _session.getUser();

    if (!mounted) return;

    if (user != null) {
      // ─── Session restore path ───
      // Start push + listener BEFORE navigating — otherwise a remembered
      // user gets no notifications until they log in again.
      try {
        await _push.initialize(user.email);
        await AppNotificationListener().start(
          userEmail: user.email,
          userRole: user.role,
          userSiteIds: user.siteIds,
        );
      } catch (e) {
        print('Session restore: notification setup failed: $e');
      }

      if (!mounted) return;
      RoleRouter.goToDashboard(context, user, replace: true);
    } else {
      // No saved session — go to login
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackground(
        overlayOpacity: 0.6,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 120),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Support at your service',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.8),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}