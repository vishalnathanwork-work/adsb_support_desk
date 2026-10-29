import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/auth/verify_email_screen.dart';

class RoleRouter {
  static void goToDashboard(
      BuildContext context,
      UserModel user, {
        bool replace = false,
      }) {
    // ⭐ 1. Not verified → VerifyEmailScreen
    if (!user.isVerified) {
      final route = MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(email: user.email),
      );
      if (replace) {
        Navigator.of(context).pushReplacement(route);
      } else {
        Navigator.of(context).pushAndRemoveUntil(route, (r) => false);
      }
      return;
    }

    // ⭐ 2. Not active OR not approved → PendingApprovalScreen
    if (!user.isActive || user.approvalStatus != 'approved') {
      final route = MaterialPageRoute(
        builder: (_) => PendingApprovalScreen(user: user),
      );
      if (replace) {
        Navigator.of(context).pushReplacement(route);
      } else {
        Navigator.of(context).pushAndRemoveUntil(route, (r) => false);
      }
      return;
    }

    // ⭐ 3. Normal role routing
    final route = _routeForRole(user.role);

    if (replace) {
      Navigator.of(context).pushReplacementNamed(route, arguments: user);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
            (r) => false,
        arguments: user,
      );
    }
  }

  static String _routeForRole(String role) {
    switch (role) {
      case 'owner': return '/owner';
      case 'operator': return '/operator';
      case 'adsb': return '/adsb';
      case 'technician': return '/technician';
      case 'onsite': return '/onsite';
      case 'admin': return '/admin';
      default: return '/login';
    }
  }
}