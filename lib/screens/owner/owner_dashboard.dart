import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../common/ticket_history_screen.dart';
import '../main_navigation.dart';
import 'owner_home_tab.dart';
import 'owner_tickets_tab.dart';
import 'owner_profile_tab.dart';
import 'notifications_screen.dart';

class OwnerDashboard extends StatefulWidget {
  final UserModel user;

  const OwnerDashboard({super.key, required this.user});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final _session = SessionService();

  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: OwnerHomeTab(
            user: widget.user,
            onLogout: _logout,
          ),
        ),
        NavTab(
          label: 'Tickets',
          icon: Icons.confirmation_number_outlined,
          page: OwnerTicketsTab(user: widget.user),
        ),
        NavTab(
          label: 'Alerts',
          icon: Icons.notifications_outlined,
          page: NotificationsScreen(user: widget.user),
        ),
        NavTab(
          label: 'History',
          icon: Icons.history,
          page: TicketHistoryScreen(
            user: widget.user,
            title: 'Ticket History',
            loader: () => TicketService().getHistoryForSites(widget.user.siteIds),
          ),
        ),
        NavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          page: OwnerProfileTab(
            user: widget.user,
            onLogout: _logout,
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    await _session.clear();
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }
}