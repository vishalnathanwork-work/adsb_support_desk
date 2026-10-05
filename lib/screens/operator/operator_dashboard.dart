import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import '../main_navigation.dart';
import '../client/client_home_tab.dart';
import '../client/client_tickets_tab.dart';
import '../client/client_profile_tab.dart';
import '../client/notifications_screen.dart';
import 'operator_sites_screen.dart';

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
          page: _OperatorHome(user: user),
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

class _OperatorHome extends StatelessWidget {
  final UserModel user;

  const _OperatorHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SessionService().clear();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00838F), Color(0xFF006064)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Operator Account',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(user.company ?? 'Parken Sdn Bhd',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick create ticket button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientHomeTab(
                        user: user,
                        onLogout: () {},
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create Ticket for Client',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tools
            const Text('Operator Tools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _toolTile(
              context,
              Icons.add_circle_outline,
              'Create Ticket for Client',
              'Submit on behalf of the client',
              AppColors.primary,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientHomeTab(
                    user: user,
                    onLogout: () {},
                  ),
                ),
              ),
            ),
            _toolTile(
              context,
              Icons.list_alt_outlined,
              'My Tickets',
              'Tickets you have submitted',
              AppColors.accent,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientTicketsTab(user: user),
                ),
              ),
            ),
            _toolTile(
              context,
              Icons.location_city_outlined,
              'Sites Under My Care',
              'View all your site locations',
              AppColors.warning,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OperatorSitesScreen(user: user),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
