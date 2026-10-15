import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../common/ticket_history_screen.dart';
import '../main_navigation.dart';
import '../owner/owner_profile_tab.dart';
import '../onsite/onsite_queue_screen.dart';
import 'adsb_queue_screen.dart';

class AdsbDashboard extends StatefulWidget {
  final UserModel user;

  const AdsbDashboard({super.key, required this.user});

  @override
  State<AdsbDashboard> createState() => _AdsbDashboardState();
}

class _AdsbDashboardState extends State<AdsbDashboard> {
  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: _AdsbHome(user: widget.user),
        ),
        NavTab(
          label: 'Verify',
          icon: Icons.support_agent,
          page: AdsbQueueScreen(user: widget.user),
        ),
        NavTab(
          label: 'On-Site',
          icon: Icons.location_on_outlined,
          page: OnsiteQueueScreen(user: widget.user),
        ),
        NavTab(
          label: 'History',
          icon: Icons.history,
          page: TicketHistoryScreen(
            user: widget.user,
            title: 'Ticket History',
            loader: () => TicketService().getAllTickets(),
          ),
        ),
        NavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          page: OwnerProfileTab(
            user: widget.user,
            onLogout: () async {
            await SessionService().clear();
            await AuthService().logout();   // ← now stops listener too
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

class _AdsbHome extends StatelessWidget {
  final UserModel user;

  const _AdsbHome({required this.user});

  @override
  Widget build(BuildContext context) {
    final service = TicketService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADSB Support Team'),
      ),
      body: SafeArea(
        child: StreamBuilder<Map<String, int>>(
          stream: service.streamAdsbStats(),
          builder: (context, snapshot) {
            final verifyCount = snapshot.data?['verify'] ?? 0;
            final onsiteCount = snapshot.data?['onsite'] ?? 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Welcome card ───
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Support Team',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Live stat cards ───
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'To Verify',
                        '$verifyCount',
                        AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'On-Site',
                        '$onsiteCount',
                        AppColors.accent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                _actionTile(
                  context,
                  Icons.support_agent,
                  'Verification Queue',
                  'Chat or call clients',
                  AppColors.primary,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdsbQueueScreen(user: user),
                    ),
                  ),
                ),
                _actionTile(
                  context,
                  Icons.location_on_outlined,
                  'On-Site Jobs',
                  'Jobs assigned for physical visit',
                  AppColors.accent,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnsiteQueueScreen(user: user),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}