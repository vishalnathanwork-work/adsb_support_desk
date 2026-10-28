import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import '../../services/auth_service.dart';
import '../../services/ticket_service.dart';
import '../../widgets/action_tile.dart';
import '../../widgets/stat_card.dart';
import '../main_navigation.dart';
import '../owner/owner_profile_tab.dart';
import 'technician_queue_screen.dart';
import 'technician_history_screen.dart';

class TechnicianDashboard extends StatefulWidget {
  final UserModel user;

  const TechnicianDashboard({super.key, required this.user});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  final _authService = AuthService();
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
            stream: _ticketService.streamTTQueueTickets(),
            builder: (context, snapshot) {
              final tickets = snapshot.data ?? [];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData;

              final queueCount =
                  tickets.where((t) => t.status == 'verified').length;

              final handledCount = tickets
                  .where((t) =>
              t.assignedTo == widget.user.email &&
                  (t.status == 'in_progress' ||
                      t.status == 'resolved' ||
                      t.status == 'closed'))
                  .length;

              return _TTAdvisorHome(
                user: widget.user,
                queueCount: queueCount,
                handledCount: handledCount,
                isLoading: isLoading,
                onRefresh: () {},
              );
            },
          ),
        ),
        NavTab(
          label: t.tabVerify,
          icon: Icons.rate_review_outlined,
          page: TechnicianQueueScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabHistory,
          icon: Icons.history,
          page: TechnicianHistoryScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabProfile,
          icon: Icons.person_outline,
          page: ClientProfileTab(
            user: widget.user,
            onLogout: () async {
              await SessionService().clear();
              await _authService.logout();
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

class _TTAdvisorHome extends StatelessWidget {
  final UserModel user;
  final int queueCount;
  final int handledCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _TTAdvisorHome({
    required this.user,
    required this.queueCount,
    required this.handledCount,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(t.technicalAdvisor)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5E35B1), Color(0xFF4527A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.technicalAdvisor,
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
                  const SizedBox(height: 8),
                  Text(
                    user.company ?? 'Access Digital Sdn Bhd',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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
                    label: t.pending,
                    value: isLoading ? '…' : '$queueCount',
                    icon: Icons.pending_outlined,
                    color: AppColors.warning,
                    variant: StatCardVariant.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: t.handled,
                    value: isLoading ? '…' : '$handledCount',
                    icon: Icons.check_circle_outline,
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
              icon: Icons.rate_review_outlined,
              title: t.reviewQueue,
              subtitle: t.reviewHint,
              accentColor: AppColors.primary,
              variant: ActionTileVariant.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TechnicianQueueScreen(user: user),
                ),
              ),
            ),
            ActionTile(
              icon: Icons.history,
              title: t.myHistory,
              subtitle: t.historyHint,
              accentColor: AppColors.accentDark,
              variant: ActionTileVariant.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TechnicianHistoryScreen(user: user),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}