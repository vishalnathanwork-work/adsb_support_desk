import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../owner/owner_profile_tab.dart';
import '../main_navigation.dart';
import 'onsite_queue_screen.dart';

class OnsiteDashboard extends StatefulWidget {
  final UserModel user;

  const OnsiteDashboard({super.key, required this.user});

  @override
  State<OnsiteDashboard> createState() => _OnsiteDashboardState();
}

class _OnsiteDashboardState extends State<OnsiteDashboard> {
  final _ticketService = TicketService();

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
            stream: _ticketService.streamOnsiteQueue(),
            builder: (context, snapshot) {
              final tickets = snapshot.data ?? [];
              final unclaimed = tickets
                  .where((t) => t.status == 'pending_onsite')
                  .length;
              final myJobs = tickets
                  .where((t) =>
              t.status == 'in_progress' &&
                  t.assignedTo == widget.user.email)
                  .length;
              return _OnsiteHome(
                user: widget.user,
                unclaimedCount: unclaimed,
                myJobsCount: myJobs,
                onRefresh: () {},
              );
            },
          ),
        ),
        NavTab(
          label: t.tabOnSite,
          icon: Icons.work_outline,
          page: OnsiteQueueScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabProfile,
          icon: Icons.person_outline,
          page: ClientProfileTab(
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

class _OnsiteHome extends StatelessWidget {
  final UserModel user;
  final int unclaimedCount;
  final int myJobsCount;
  final VoidCallback onRefresh;

  const _OnsiteHome({
    required this.user,
    required this.unclaimedCount,
    required this.myJobsCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.tabOnSite)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFBF360C)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.onSiteTechnician,
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
              t.yourStats,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    label: t.unclaimed,
                    value: '$unclaimedCount',
                    color: AppColors.warning,
                    icon: Icons.inbox_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    label: t.myJobs,
                    value: '$myJobsCount',
                    color: AppColors.primary,
                    icon: Icons.work_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              t.quickActions,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _actionTile(
              context,
              Icons.work_outline,
              t.myJobsTitle,
              t.viewJobsHint,
              AppColors.primary,
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OnsiteQueueScreen(user: user),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
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