import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../widgets/stat_card.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final siteIds = widget.user.siteIds;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(t.tabHome)),
      body: SafeArea(
        child: siteIds.isEmpty
            ? _noSitesView(t)
            : StreamBuilder<List<Ticket>>(
          stream: _service.streamActiveTicketsForSites(siteIds),
          builder: (context, snapshot) {
            final tickets = snapshot.data ?? [];

            final pending = tickets
                .where((ticket) => ticket.status == 'pending')
                .length;

            final active = tickets
                .where((ticket) =>
            ticket.status == 'verified' ||
                ticket.status == 'pending_onsite' ||
                ticket.status == 'in_progress')
                .length;

            final resolved = tickets
                .where((ticket) =>
            ticket.status == 'resolved' ||
                ticket.status == 'closed')
                .length;

            return RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(
                    const Duration(milliseconds: 300));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _welcomeCard(t),
                  const SizedBox(height: 20),
                  _statsRow(t, pending, active, resolved),
                  const SizedBox(height: 24),
                  _createButton(t),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _noSitesView(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              t.noSitesAssigned,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              t.contactAdmin,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, size: 18),
                label: Text(t.logOut),
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

  Widget _welcomeCard(AppLocalizations t) {
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
            '${t.welcomeBack},',
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

  Widget _statsRow(
      AppLocalizations t, int pending, int active, int resolved) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: t.pending,
            value: '$pending',
            icon: Icons.pending_outlined,
            color: AppColors.primary,
            variant: StatCardVariant.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: t.active,
            value: '$active',
            icon: Icons.autorenew,
            color: AppColors.accentDark,
            variant: StatCardVariant.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: t.resolved,
            value: '$resolved',
            icon: Icons.check_circle_outline,
            color: AppColors.accentDark,
            variant: StatCardVariant.green,
          ),
        ),
      ],
    );
  }

  Widget _createButton(AppLocalizations t) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(
          t.createTicket,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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