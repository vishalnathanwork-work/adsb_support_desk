import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../common/ticket_history_screen.dart';
import '../owner/create_ticket_screen.dart';
import '../owner/owner_profile_tab.dart';
import '../owner/owner_tickets_tab.dart';
import '../owner/notifications_screen.dart';
import '../main_navigation.dart';

class OperatorDashboard extends StatefulWidget {
  final UserModel user;

  const OperatorDashboard({super.key, required this.user});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  int _activeCount = 0;
  int _pendingCount = 0;
  int _resolvedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final service = TicketService();

    List siteTickets = [];
    if (widget.user.siteIds.isNotEmpty) {
      siteTickets = await service.getActiveTicketsForSites(widget.user.siteIds);
    }

    final allTickets = widget.user.siteIds.isNotEmpty
        ? await service.getTicketsForSites(widget.user.siteIds)
        : [];

    if (!mounted) return;
    setState(() {
      _activeCount = siteTickets
          .where((t) =>
      t.status != 'resolved' &&
          t.status != 'closed' &&
          t.status != 'cancelled')
          .length;
      _pendingCount =
          siteTickets.where((t) => t.status == 'pending').length;
      _resolvedCount = allTickets
          .where((t) => t.status == 'resolved' || t.status == 'closed')
          .length;
    });
  }

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
    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          page: _OperatorHome(
            user: widget.user,
            activeCount: _activeCount,
            pendingCount: _pendingCount,
            resolvedCount: _resolvedCount,
            onRefresh: _loadStats,
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
            onLogout: () async {
              await SessionService().clear();
              await AuthService().logout();
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
  final int activeCount;
  final int pendingCount;
  final int resolvedCount;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const _OperatorHome({
    required this.user,
    required this.activeCount,
    required this.pendingCount,
    required this.resolvedCount,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Welcome card ───
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
                    const Text(
                      'Welcome back,',
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
                    if ((user.company ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        user.company!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── Stats ───
              const Text(
                'Ticket Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      label: 'Active',
                      value: '$activeCount',
                      icon: Icons.sync,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      label: 'Pending',
                      value: '$pendingCount',
                      icon: Icons.pending_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      label: 'Resolved',
                      value: '$resolvedCount',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ─── Quick actions ───
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
                Icons.confirmation_number_outlined,
                'My Tickets',
                'View and manage all tickets at your site',
                AppColors.primary,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerTicketsTab(user: user),
                    ),
                  );
                },
              ),
              _actionTile(
                context,
                Icons.add_circle_outline,
                'Create Ticket',
                'Create a new ticket for your site',
                AppColors.accent,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTicketScreen(user: user),   // ← RIGHT
                    ),
                  );
                },
              ),
              _actionTile(
                context,
                Icons.notifications_outlined,
                'Notifications',
                'Check your alerts',
                AppColors.warning,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(user: user),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
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
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}