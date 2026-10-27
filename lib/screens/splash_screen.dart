import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../l10n/app_localizations.dart';
import '../services/session_service.dart';
import '../services/push_notification_service.dart';
import '../services/notification_listener.dart';
import '../utils/role_router.dart';
import '../widgets/app_logo.dart';

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
    await Future.delayed(const Duration(milliseconds: 800));

    final user = await _session.getUser();

    if (!mounted) return;

    if (user != null) {
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
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,   // ⭐ see global image
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 120),
              const SizedBox(height: 24),
              // Dark text since the background image is behind us —
              // text will still be readable thanks to the global 35% white veil.
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,           // ⭐ white for contrast
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.appSubtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white.withOpacity(0.9),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}