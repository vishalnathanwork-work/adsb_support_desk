import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/status_badge.dart';
import 'admin_ticket_control_screen.dart';

class AdminAllTicketsScreen extends StatefulWidget {
  final UserModel user;

  const AdminAllTicketsScreen({super.key, required this.user});

  @override
  State<AdminAllTicketsScreen> createState() =>
      _AdminAllTicketsScreenState();
}

class _AdminAllTicketsScreenState extends State<AdminAllTicketsScreen> {
  final _service = TicketService();
  List<Ticket> _all = [];
  List<Ticket> _filtered = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _service.getAllTickets();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _all = list;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    _filtered = _all.where((t) {
      final statusMatch =
          _filterStatus == 'all' || t.status == _filterStatus;
      final searchMatch = q.isEmpty ||
          t.id.toLowerCase().contains(q) ||
          t.productType.toLowerCase().contains(q) ||
          t.createdByName.toLowerCase().contains(q);
      return statusMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.adminAllTicketsTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(_applyFilter),
                  decoration: InputDecoration(
                    hintText: t.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 8),
                FilterChipRow(
                  selectedValue: _filterStatus,
                  onSelected: (v) {
                    setState(() {
                      _filterStatus = v;
                      _applyFilter();
                    });
                  },
                  options: [
                    FilterOption(
                      label: t.notificationsTabAll,
                      value: 'all',
                    ),
                    FilterOption(label: t.pending, value: 'pending'),
                    FilterOption(
                      label: t.statusVerifiedLabel,
                      value: 'verified',
                    ),
                    FilterOption(
                      label: t.onSiteQueued,
                      value: 'pending_onsite',
                    ),
                    FilterOption(
                      label: t.statusInProgressLabel,
                      value: 'in_progress',
                    ),
                    FilterOption(label: t.resolved, value: 'resolved'),
                    FilterOption(
                      label: t.statusClosedLabel,
                      value: 'closed',
                    ),
                    FilterOption(
                      label: t.statusCancelledLabel,
                      value: 'cancelled',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? EmptyState(
              icon: Icons.search_off,
              title: t.ttNoTickets,
              subtitle: t.ttTryChangeFilter,
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final ticket = _filtered[i];
                  return InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminTicketControlScreen(
                                ticketId: ticket.id,
                                admin: widget.user,
                              ),
                        ),
                      );
                      _load();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin:
                      const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.divider,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ticket.id,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                status: ticket.status,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ticket.productType,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ticket.productIssue,
                            style: const TextStyle(
                              fontSize: 12,
                              color:
                              AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (ticket.totalResolutionTime !=
                              null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 6,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 12,
                                    color: AppColors
                                        .textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${t.adminReportedLabel}: '
                                        '${Ticket.formatDuration(ticket.totalResolutionTime)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors
                                          .textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 12,
                                color: AppColors
                                    .textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${ticket.createdByName} (${ticket.createdByRoleLabel})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors
                                        .textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormatter.relative(
                                  ticket.createdAt,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors
                                      .textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}