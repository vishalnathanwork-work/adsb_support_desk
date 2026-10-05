import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/session_service.dart';
import '../../services/ticket_service.dart';
import '../main_navigation.dart';
import '../client/client_profile_tab.dart';
import 'adsb_queue_screen.dart';

class AdsbDashboard extends StatefulWidget {
  final UserModel user;

  const AdsbDashboard({super.key, required this.user});

  @override
  State<AdsbDashboard> createState() => _AdsbDashboardState();
}

class _AdsbDashboardState extends State<AdsbDashboard> {
  int _pendingCount = 0;
  int _myActiveCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final all = await TicketService().getPendingTickets();
    final pending = all.where((t) => t.assignedTo == null).length;
    final mine = all.where((t) => t.assignedTo == widget.user.email).length;
    if (!mounted) return;
    setState(() {
      _pendingCount = pending;
      _myActiveCount = mine;
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
          page: _AdsbHome(
            user: widget.user,
            pendingCount: _pendingCount,
            myActiveCount: _myActiveCount,
            onRefresh: _loadStats,
          ),
        ),
        NavTab(
          label: 'Queue',
          icon: Icons.list_alt_outlined,
          page: AdsbQueueScreen(user: widget.user),
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

class _AdsbHome extends StatelessWidget {
  final UserModel user;
  final int pendingCount;
  final int myActiveCount;
  final VoidCallback onRefresh;

  const _AdsbHome({
    required this.user,
    required this.pendingCount,
    required this.myActiveCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADSB Support Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
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
                  const Text('First-Line Support',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
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
            Row(
              children: [
                Expanded(
                  child: _statCard(
                      'Unassigned', '$pendingCount', AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                      'My Active', '$myActiveCount', AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _actionTile(
              context,
              Icons.support_agent,
              'Verification Queue',
              'Tickets awaiting verification',
              AppColors.primary,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdsbQueueScreen(user: user),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
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
