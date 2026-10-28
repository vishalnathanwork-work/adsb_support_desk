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
                  .where((tk) => tk.status == 'pending_onsite')
                  .length;
              final myJobs = tickets
                  .where((tk) =>
              tk.status == 'in_progress' &&
                  tk.assignedTo == widget.user.email)
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
      backgroundColor: Colors.transparent,
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
                  child: StatCard(
                    label: t.unclaimed,
                    value: '$unclaimedCount',
                    icon: Icons.inbox_outlined,
                    color: AppColors.warning,
                    variant: StatCardVariant.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: t.myJobs,
                    value: '$myJobsCount',
                    icon: Icons.work_outline,
                    color: AppColors.primary,
                    variant: StatCardVariant.blue,
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
            ActionTile(
              icon: Icons.work_outline,
              title: t.myJobsTitle,
              subtitle: t.viewJobsHint,
              accentColor: AppColors.primary,
              variant: ActionTileVariant.blue,
              onTap: () => Navigator.push(
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
}