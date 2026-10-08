import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'config/routes.dart';
import 'models/user_model.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_dashboard.dart';
import 'screens/operator/operator_dashboard.dart';
import 'screens/adsb/adsb_dashboard.dart';
import 'screens/technician/technician_dashboard.dart';
import 'screens/onsite/onsite_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';

class AdsbSupportApp extends StatelessWidget {
  const AdsbSupportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
      },
      onGenerateRoute: (settings) {
        final user = settings.arguments as UserModel?;

        switch (settings.name) {
          case AppRoutes.clientDashboard:
            if (user == null) return _fallbackLogin();
            return MaterialPageRoute(
              builder: (_) => ClientDashboard(user: user),
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
  }

  static MaterialPageRoute _fallbackLogin() =>
      MaterialPageRoute(builder: (_) => const LoginScreen());
}