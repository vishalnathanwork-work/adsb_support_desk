import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../l10n/app_localizations.dart';
import '../services/session_service.dart';
import '../services/session_guard_service.dart';
import '../services/push_notification_service.dart';
import '../services/notification_listener.dart';
import '../services/auth_service.dart';
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

    // ⭐ Check Firebase Auth first — this is the true authority
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      // No Firebase session → login
      await _session.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // ⭐ Fetch FRESH user from Firestore
    final freshUser = await AuthService().getCurrentUserProfile();

    if (!mounted) return;

    if (freshUser == null) {
      // User doc gone (deleted/deactivated)
      await _session.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // ⭐ Save fresh user to local cache
    try {
      await _session.saveUser(freshUser);
    } catch (_) {}

    // ⭐ Session guard verification (single-device login)
    final localSessionId = await _session.getSessionId();
    final isValidSession =
    await SessionGuardService().verifyRestoredSession(localSessionId);

    if (!mounted) return;

    if (!isValidSession) {
      await _session.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // Setup notifications
    try {
      await _push.initialize(freshUser.email);
      await AppNotificationListener().start(
        userEmail: freshUser.email,
        userRole: freshUser.role,
        userSiteIds: freshUser.siteIds,
      );
      if (localSessionId != null) {
        await SessionGuardService().restoreListener(localSessionId);
      }
    } catch (e) {
      debugPrint('Splash: setup failed: $e');
    }

    if (!mounted) return;
    RoleRouter.goToDashboard(context, freshUser, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
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
                  shadows: [
                    Shadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2)),
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
                        offset: Offset(0, 1)),
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