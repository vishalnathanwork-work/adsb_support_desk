import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/action_tile.dart';
import '../../widgets/stat_card.dart';
import '../main_navigation.dart';
import '../owner/owner_profile_tab.dart';
import '../owner/notifications_screen.dart';
import 'admin_all_ticket_screen.dart';
import 'admin_team_management_screen.dart';
import 'admin_users_screen.dart';
import 'admin_preset_management_screen.dart';
import 'admin_clients_screen.dart';
import 'admin_sites_screen.dart';
import 'analytics_screen.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _ticketService = TicketService();

  Future<void> _logout() async {
    await SessionService().clear();
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: t.tabHome,
          icon: Icons.home_outlined,
          page: StreamBuilder<List<Ticket>>(
            stream: _ticketService.streamAllTickets(),
            builder: (context, snapshot) {
              final tickets = snapshot.data ?? [];
              final loading =
                  snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData;
              return _AdminHome(
                user: widget.user,
                tickets: tickets,
                isLoading: loading,
                onRefresh: () {},
              );
            },
          ),
        ),
        NavTab(
          label: t.tabTickets,
          icon: Icons.confirmation_number_outlined,
          page: AdminAllTicketsScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabTeams,
          icon: Icons.groups_outlined,
          page: AdminTeamManagementScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabAlerts,
          icon: Icons.notifications_outlined,
          page: NotificationsScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabProfile,
          icon: Icons.person_outline,
          page: OwnerProfileTab(
            user: widget.user,
            onLogout: _logout,
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
    final t = AppLocalizations.of(context)!;

    final total = tickets.length;
    final open = tickets
        .where((t) =>
    t.status == 'pending' ||
        t.status == 'verified' ||
        t.status == 'pending_onsite' ||
        t.status == 'in_progress')
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(t.administrator)),
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
                  Text(
                    t.administrator,
                    style: const TextStyle(
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
            Text(
              t.keyMetrics,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: t.total,
                      value: '$total',
                      icon: Icons.list_alt_outlined,
                      color: AppColors.primary,
                      variant: StatCardVariant.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: t.open,
                      value: '$open',
                      icon: Icons.pending_outlined,
                      color: AppColors.warning,
                      variant: StatCardVariant.warning,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Text(
              t.management,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ActionTile(
              icon: Icons.confirmation_number_outlined,
              title: t.allTicketsTitle,
              subtitle: t.allTicketsHint,
              accentColor: AppColors.primary,
              variant: ActionTileVariant.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminAllTicketsScreen(user: user),
                ),
              ),
            ),
            ActionTile(
              icon: Icons.groups_outlined,
              title: t.teamManagement,
              subtitle: t.teamManagementHint,
              accentColor: AppColors.accent,
              variant: ActionTileVariant.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminTeamManagementScreen(user: user),
                ),
              ),
            ),
            ActionTile(
              icon: Icons.people_outline,
              title: t.userManagement,
              subtitle: t.userManagementHint,
              accentColor: AppColors.warning,
              variant: ActionTileVariant.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminUsersScreen(user: user),
                ),
              ),
            ),
            ActionTile(
              icon: Icons.business_outlined,
              title: t.clientsTitle,
              subtitle: t.clientsHint,
              accentColor: AppColors.primary,
              variant: ActionTileVariant.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminClientsScreen(),
                ),
              ),
            ),
            ActionTile(
              icon: Icons.location_city_outlined,
              title: t.sitesTitle,
              subtitle: t.sitesHint,
              accentColor: AppColors.accentDark,
              variant: ActionTileVariant.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminSitesScreen(),
                ),
              ),
            ),
            ActionTile(
              icon: Icons.tune,
              title: t.systemPresets,
              subtitle: t.systemPresetsHint,
              accentColor: AppColors.textSecondary,
              variant: ActionTileVariant.gray,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPresetManagementScreen(),
                ),
              ),
            ),
            ActionTile(
              icon: Icons.analytics_outlined,
              title: t.analytics,
              subtitle: t.analyticsHint,
              accentColor: AppColors.success,
              variant: ActionTileVariant.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AnalyticsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}