import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../services/notification_listener.dart';
import '../services/session_service.dart';
import '../utils/role_router.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _session = SessionService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }


  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final user = await _session.getUser();

    if (!mounted) return;

    if (user != null) {
      // Start notifications for the logged-in user
      await AppNotificationListener().start(
        userEmail: user.email,
        userRole: user.role,
        userSiteIds: user.siteIds,
      );

      if (!mounted) return;

      // Navigate to the appropriate dashboard
      RoleRouter.goToDashboard(context, user, replace: true);
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 110),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}