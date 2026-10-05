import 'package:flutter/material.dart';
import '../models/user_model.dart';

class RoleRouter {
  static void goToDashboard(
      BuildContext context,
      UserModel user, {
        bool replace = false,
      }) {
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
      case 'client':
        return '/client';
      case 'operator':
        return '/operator';
      case 'adsb':
        return '/adsb';
      case 'technician':
        return '/technician';
      case 'admin':
        return '/admin';
      default:
        return '/login';
    }
  }
}