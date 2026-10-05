import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../main_navigation.dart';
import '../client/client_profile_tab.dart';
import 'technician_queue_screen.dart';
import 'technician_history_screen.dart';

class TechnicianDashboard extends StatefulWidget {
  final UserModel user;

  const TechnicianDashboard({super.key, required this.user});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  int _queueCount = 0;
  int _handledCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final service = TicketService();
    final queue = await service.getVerifiedTickets();
    final all = await service.getAllTickets();

    // Tickets that TT has already provided advice on
    final handled = all
        .where((t) =>
    t.assignedTo == widget.user.email &&
        t.assignedToName == widget.user.name &&
        (t.status == 'in_progress' ||
            t.status == 'resolved' ||
            t.status == 'closed'))
        .length;

    if (!mounted) return;
    setState(() {
      _queueCount = queue.length;
      _handledCount = handled;
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
          page: _TTAdvisorHome(
            user: widget.user,
            queueCount: _queueCount,
            handledCount: _handledCount,
            onRefresh: _loadStats,
          ),
        ),
        NavTab(
          label: 'Reviews',
          icon: Icons.rate_review_outlined,
          page: TechnicianQueueScreen(user: widget.user),
        ),
        NavTab(
          label: 'History',
          icon: Icons.history,
          page: TechnicianHistoryScreen(user: widget.user),
        ),
        NavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          page: ClientProfileTab(
            user: widget.user,
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

class _TTAdvisorHome extends StatelessWidget {
  final UserModel user;
  final int queueCount;
  final int handledCount;
  final VoidCallback onRefresh;

  const _TTAdvisorHome({
    required this.user,
    required this.queueCount,
    required this.handledCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technical Advisor'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh),
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
                  colors: [Color(0xFF5E35B1), Color(0xFF4527A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Technical Advisor',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(user.company ?? 'Access Digital Sdn Bhd',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            const Text('Your Stats',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    label: 'Pending',
                    value: '$queueCount',
                    icon: Icons.pending_outlined,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    label: 'Handled',
                    value: '$handledCount',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your role: Analyze escalated tickets, provide root cause advice, and assign the ADSB on-site team to attend the location.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick actions
            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _actionTile(
              context,
              Icons.rate_review_outlined,
              'Review Queue',
              'Analyze escalated tickets',
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
              'My History',
              'Tickets you previously handled',
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
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
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