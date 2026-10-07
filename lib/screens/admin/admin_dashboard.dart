import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_listener.dart';
import '../../services/session_service.dart';
import '../../services/auth_service.dart';
import '../../services/ticket_service.dart';
import '../main_navigation.dart';
import '../client/client_profile_tab.dart';
import 'admin_all_ticket_screen.dart';
import 'admin_team_management_screen.dart';
import 'admin_users_screen.dart';
import 'admin_preset_management_screen.dart';
import 'data_inspector_screen.dart';
import 'analytics_screen.dart';


class AdminDashboard extends StatefulWidget {
  final UserModel user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Ticket> _all = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await TicketService().getAllTickets();
    if (!mounted) return;
    setState(() {
      _all = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: _AdminHome(
            user: widget.user,
            tickets: _all,
            isLoading: _isLoading,
            onRefresh: _load,
          ),
        ),
        NavTab(
          label: 'Tickets',
          icon: Icons.confirmation_number_outlined,
          page: AdminAllTicketsScreen(user: widget.user),
        ),
        NavTab(
          label: 'Teams',
          icon: Icons.groups_outlined,
          page: AdminTeamManagementScreen(user: widget.user),
        ),
        NavTab(
          label: 'Users',
          icon: Icons.people_outline,
          page: AdminUsersScreen(user: widget.user),
        ),
        NavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          page: ClientProfileTab(
            user: widget.user,
            onLogout: () async {
              AppNotificationListener().stop();
              await SessionService().clear();
              final authService = AuthService();
              await authService.logout();
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
  final List<Ticket> tickets;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _AdminHome({
    required this.user,
    required this.tickets,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final total = tickets.length;
    final open = tickets
        .where((t) =>
    t.status == 'pending' ||
        t.status == 'verified' ||
        t.status == 'in_progress')
        .length;
    final resolved =
        tickets.where((t) => t.status == 'resolved' || t.status == 'closed').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRefresh(),
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
                        style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
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
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard('Total', '$total',
                            Icons.list_alt_outlined, AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard('Open', '$open',
                            Icons.pending_outlined, AppColors.warning),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                            'Resolved',
                            '$resolved',
                            Icons.check_circle_outline,
                            AppColors.success),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard('Avg Time', '—',
                            Icons.timer_outlined, AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Management',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _actionTile(
                context,
                Icons.confirmation_number_outlined,
                'All Tickets',
                'View and manage all tickets',
                AppColors.primary,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminAllTicketsScreen(user: user),
                  ),
                ),
              ),
              _actionTile(
                context,
                Icons.groups_outlined,
                'Team Management',
                'ADSB + TT members',
                AppColors.accent,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminTeamManagementScreen(user: user),
                  ),
                ),
              ),
              _actionTile(
                context,
                Icons.people_outline,
                'User Management',
                'Clients and operators',
                AppColors.warning,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminUsersScreen(user: user),
                  ),
                ),
              ),
              _actionTile(
                context,
                Icons.tune,
                'System Presets',
                'Product types, issues, sites',
                AppColors.textSecondary,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminPresetManagementScreen(),
                  ),
                ),
              ),

              _actionTile(
                context,
                Icons.analytics_outlined,
                'Analytics & Reporting',
                'KPIs, trends, insights',
                AppColors.success,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AnalyticsScreen(),
                  ),
                ),
              ),
              _actionTile(
                context,
                Icons.storage_outlined,
                'Data Inspector',
                'View all locally stored data',
                const Color(0xFF7C3AED),
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DataInspectorScreen(),
                  ),
                ),
              ),
            ],
          ),
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
      ),
    );
  }
}