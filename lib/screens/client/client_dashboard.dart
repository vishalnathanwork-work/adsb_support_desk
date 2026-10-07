import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/notification_listener.dart';
import '../../services/session_service.dart';
import '../main_navigation.dart';
import 'client_home_tab.dart';
import 'client_tickets_tab.dart';
import 'client_profile_tab.dart';
import 'notifications_screen.dart';

class ClientDashboard extends StatefulWidget {
  final UserModel user;

  const ClientDashboard({super.key, required this.user});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final _session = SessionService();

  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: ClientHomeTab(
            user: widget.user,
            onLogout: _logout,
          ),
        ),
        NavTab(
          label: 'Tickets',
          icon: Icons.confirmation_number_outlined,
          page: ClientTicketsTab(user: widget.user),
        ),
        NavTab(
          label: 'Alerts',
          icon: Icons.notifications_outlined,
          page: NotificationsScreen(user: widget.user),
        ),
        NavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          page: ClientProfileTab(
            user: widget.user,
            onLogout: _logout,
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    AppNotificationListener().stop();
    await _session.clear();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }
}
