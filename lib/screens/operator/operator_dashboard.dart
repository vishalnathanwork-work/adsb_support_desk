import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/site_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/site_service.dart';
import '../../services/ticket_service.dart';
import '../common/ticket_history_screen.dart';
import '../main_navigation.dart';
import '../owner/create_ticket_screen.dart';
import '../owner/owner_profile_tab.dart';
import '../owner/owner_tickets_tab.dart';
import '../owner/notifications_screen.dart';

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
      siteTickets =
      await service.getActiveTicketsForSites(widget.user.siteIds);
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
    final t = AppLocalizations.of(context)!;

    return MainNavigation(
      user: widget.user,
      tabs: [
        NavTab(
          label: t.tabHome,
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
          label: t.tabTickets,
          icon: Icons.confirmation_number_outlined,
          page: OwnerTicketsTab(user: widget.user),
        ),
        NavTab(
          label: t.tabAlerts,
          icon: Icons.notifications_outlined,
          page: NotificationsScreen(user: widget.user),
        ),
        NavTab(
          label: t.tabHistory,
          icon: Icons.history,
          page: TicketHistoryScreen(
            user: widget.user,
            title: t.tabHistory,
            loader: () =>
                TicketService().getHistoryForSites(widget.user.siteIds),
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

// ═══════════════════════════════════════════════
// OPERATOR HOME (with site card)
// ═══════════════════════════════════════════════

class _OperatorHome extends StatefulWidget {
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
  State<_OperatorHome> createState() => _OperatorHomeState();
}

class _OperatorHomeState extends State<_OperatorHome> {
  final _siteService = SiteService();

  SiteModel? _mySite;
  bool _loadingSite = true;

  @override
  void initState() {
    super.initState();
    _loadMySite();
  }

  Future<void> _loadMySite() async {
    if (widget.user.siteIds.isEmpty) {
      setState(() => _loadingSite = false);
      return;
    }

    final site = await _siteService.getSiteById(widget.user.siteIds.first);
    if (!mounted) return;
    setState(() {
      _mySite = site;
      _loadingSite = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.operatorTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.onRefresh();
              _loadMySite();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            widget.onRefresh();
            await _loadMySite();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ═══ Welcome card ═══
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
                    Text(
                      '${t.welcomeBack},',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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
                      const SizedBox(height: 6),
                      Text(
                        widget.user.company!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ═══ MY SITE CARD ═══
              if (!_loadingSite && _mySite != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'YOUR ASSIGNED SITE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _mySite!.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.map_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _mySite!.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_mySite!.zones.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_parking_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_mySite!.zoneCount} zone${_mySite!.zoneCount == 1 ? "" : "s"} · '
                                  '${_mySite!.totalEntries} entry · '
                                  '${_mySite!.totalExits} exit',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _mySite!.zones.map((z) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                AppColors.primary.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                z.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (!_loadingSite && _mySite == null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: AppColors.warning),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'No site assigned yet. Contact admin.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ═══ Ticket overview ═══
              Text(
                t.ticketOverview,
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
                      label: t.active,
                      value: '${widget.activeCount}',
                      icon: Icons.sync,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      label: t.pending,
                      value: '${widget.pendingCount}',
                      icon: Icons.pending_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      label: t.resolved,
                      value: '${widget.resolvedCount}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

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
                Icons.confirmation_number_outlined,
                t.myJobsTitle,
                t.ticketDetailsHint,
                AppColors.primary,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerTicketsTab(user: widget.user),
                    ),
                  );
                },
              ),
              _actionTile(
                context,
                Icons.add_circle_outline,
                t.createTicket,
                t.ticketDetailsHint,
                AppColors.accent,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateTicketScreen(user: widget.user),
                    ),
                  );
                },
              ),
              _actionTile(
                context,
                Icons.notifications_outlined,
                t.notifications,
                t.checkAlertsHint,
                AppColors.warning,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationsScreen(user: widget.user),
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