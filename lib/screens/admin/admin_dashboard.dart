import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import '../main_navigation.dart';
import '../client/client_profile_tab.dart';

class AdminDashboard extends StatelessWidget {
  final UserModel user;

  const AdminDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: _AdminHome(user: user),
        ),
        NavTab(
          label: 'Tickets',
          icon: Icons.confirmation_number_outlined,
          page: _AdminAllTickets(),
        ),
        NavTab(
          label: 'Teams',
          icon: Icons.groups_outlined,
          page: _AdminTeams(),
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

class _AdminHome extends StatelessWidget {
  final UserModel user;
  const _AdminHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF333333)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Administrator',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Key Metrics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _kpiCard('Total', '0', Icons.list_alt_outlined,
                        AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                    child: _kpiCard('Open', '0', Icons.pending_outlined,
                        AppColors.warning)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _kpiCard('Resolved', '0', Icons.check_circle_outline,
                        AppColors.success)),
                const SizedBox(width: 12),
                Expanded(
                    child: _kpiCard('Avg Time', '—', Icons.timer_outlined,
                        AppColors.accent)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Management',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _actionTile(Icons.confirmation_number_outlined,
                'All Tickets', 'View and manage all tickets', AppColors.primary),
            _actionTile(Icons.groups_outlined, 'Team Management',
                'ADSB + TT members', AppColors.accent),
            _actionTile(Icons.people_outline, 'User Management',
                'Clients and operators', AppColors.warning),
            _actionTile(Icons.analytics_outlined, 'Analytics & Reporting',
                'KPIs, trends, insights', AppColors.success),
            _actionTile(Icons.tune, 'System Presets',
                'Product types, issues, solutions', AppColors.textSecondary),
            _actionTile(Icons.menu_book_outlined, 'Knowledge Base',
                'FAQ articles', AppColors.primaryDark),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionTile(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _AdminAllTickets extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Tickets')),
      body: const Center(
        child: Text('Ticket list coming soon',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

class _AdminTeams extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Management')),
      body: const Center(
        child: Text('Team list coming soon',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}