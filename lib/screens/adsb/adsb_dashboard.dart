import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/action_tile.dart';
import '../../widgets/stat_card.dart';
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
    final t = AppLocalizations.of(context)!;

    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: t.tabHome,
          icon: Icons.home_outlined,
          page: _AdsbHome(user: widget.user),
        ),
        NavTab(
          label: t.tabVerify,
          icon: Icons.support_agent,
          page: AdsbQueueScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabOnSite,
          icon: Icons.location_on_outlined,
          page: OnsiteQueueScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabHistory,
          icon: Icons.history,
          page: TicketHistoryScreen(
            user: widget.user,
            title: t.tabHistory,
            loader: () => TicketService().getAllTickets(),
          ),
        ),
        NavTab(
          label: t.tabProfile,
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

class _AdsbHome extends StatelessWidget {
  final UserModel user;

  const _AdsbHome({required this.user});

  @override
  Widget build(BuildContext context) {
    final service = TicketService();
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(t.supportTeam)),
      body: SafeArea(
        child: StreamBuilder<Map<String, int>>(
          stream: service.streamAdsbStats(),
          builder: (context, snapshot) {
            final verifyCount = snapshot.data?['verify'] ?? 0;
            final onsiteCount = snapshot.data?['onsite'] ?? 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                      Text(
                        t.supportTeam,
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
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: t.toVerify,
                        value: '$verifyCount',
                        icon: Icons.rule_outlined,
                        color: AppColors.primary,
                        variant: StatCardVariant.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: t.onSiteQueued,
                        value: '$onsiteCount',
                        icon: Icons.location_on_outlined,
                        color: AppColors.accentDark,
                        variant: StatCardVariant.green,
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
                  icon: Icons.support_agent,
                  title: t.verificationQueue,
                  subtitle: t.ticketDetailsHint,
                  accentColor: AppColors.primary,
                  variant: ActionTileVariant.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdsbQueueScreen(user: user),
                    ),
                  ),
                ),
                ActionTile(
                  icon: Icons.location_on_outlined,
                  title: t.onSiteJobs,
                  subtitle: t.jobsVisitHint,
                  accentColor: AppColors.accentDark,
                  variant: ActionTileVariant.green,
                  onTap: () => Navigator.push(
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
}