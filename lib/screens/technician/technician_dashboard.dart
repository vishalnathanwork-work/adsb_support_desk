import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import 'package:adsb_support_desk/services/auth_service.dart';
import '../../services/ticket_service.dart';
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
                  child: _statCard(
                    label: t.pending,
                    value: isLoading ? '…' : '$queueCount',
                    icon: Icons.pending_outlined,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    label: t.handled,
                    value: isLoading ? '…' : '$handledCount',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
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
              Icons.rate_review_outlined,
              t.reviewQueue,
              t.reviewHint,
              AppColors.primary,
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TechnicianQueueScreen(user: user),
                ),
              ),
            ),
            _actionTile(
              context,
              Icons.history,
              t.myHistory,
              t.historyHint,
              AppColors.accent,
                  () => Navigator.push(
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

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
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