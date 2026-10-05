import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import '../main_navigation.dart';
import '../client/client_home_tab.dart';
import '../client/client_tickets_tab.dart';
import '../client/client_profile_tab.dart';
import '../client/notifications_screen.dart';

class OperatorDashboard extends StatelessWidget {
  final UserModel user;

  const OperatorDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: ClientHomeTab(
            user: user,
            onLogout: () async {
              await SessionService().clear();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
          ),
        ),
        NavTab(
          label: 'Tickets',
          icon: Icons.confirmation_number_outlined,
          page: ClientTicketsTab(user: user),
        ),
        NavTab(
          label: 'Alerts',
          icon: Icons.notifications_outlined,
          page: NotificationsScreen(user: user),
        ),
        NavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          page: ClientProfileTab(
            user: user,
            onLogout: () async {
              await SessionService().clear();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
          ),
        ),
      ],
    );
  }
}