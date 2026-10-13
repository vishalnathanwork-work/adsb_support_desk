import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import 'create_ticket_screen.dart';

class OwnerHomeTab extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const OwnerHomeTab({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<OwnerHomeTab> createState() => _OwnerHomeTabState();
}

class _OwnerHomeTabState extends State<OwnerHomeTab> {
  final _service = TicketService();

  Future<void> _openCreate() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTicketScreen(user: widget.user),
      ),
    );
    // No reload — the stream handles new tickets.
  }

  @override
  Widget build(BuildContext context) {
    final siteIds = widget.user.siteIds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: SafeArea(
        child: siteIds.isEmpty
            ? _noSitesView()
            : StreamBuilder<List<Ticket>>(
          stream: _service.streamActiveTicketsForSites(siteIds),
          builder: (context, snapshot) {
            final tickets = snapshot.data ?? [];

            final pending = tickets
                .where((t) => t.status == 'pending')
                .length;

            final active = tickets
                .where((t) =>
            t.status == 'verified' ||
                t.status == 'pending_onsite' ||
                t.status == 'in_progress')
                .length;

            final resolved = tickets
                .where((t) =>
            t.status == 'resolved' || t.status == 'closed')
                .length;

            return RefreshIndicator(
              onRefresh: () async {
                // Stream-driven — no reload needed, but allow pull
                // for user satisfaction.
                await Future.delayed(
                    const Duration(milliseconds: 300));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _welcomeCard(),
                  const SizedBox(height: 20),
                  _statsRow(pending, active, resolved),
                  const SizedBox(height: 24),
                  _createButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _noSitesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'No sites assigned',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contact admin to assign sites to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.user.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if ((widget.user.company ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.user.company!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsRow(int pending, int active, int resolved) {
    return Row(
      children: [
        Expanded(
          child: _statCard('Pending', '$pending', AppColors.warning),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('Active', '$active', AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('Resolved', '$resolved', AppColors.success),
        ),
      ],
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
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _createButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create New Ticket',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}