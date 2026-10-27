import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/tt_status_badge.dart';
import 'technician_review_screen.dart';

class TechnicianQueueScreen extends StatefulWidget {
  final UserModel user;

  const TechnicianQueueScreen({super.key, required this.user});

  @override
  State<TechnicianQueueScreen> createState() =>
      _TechnicianQueueScreenState();
}

class _TechnicianQueueScreenState extends State<TechnicianQueueScreen> {
  final _service = TicketService();
  String _filter = 'awaiting';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.ttQueue)),
      body: StreamBuilder<List<Ticket>>(
        stream: _service.streamTTQueueTickets(),
        builder: (context, snapshot) {
          final allTickets = snapshot.data ?? [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

          final awaitingCount =
              allTickets.where((ticket) => ticket.status == 'verified').length;
          final onsiteCount = allTickets
              .where((ticket) =>
          ticket.status == 'pending_onsite' ||
              ticket.status == 'in_progress')
              .length;

          final q = _searchController.text.trim().toLowerCase();

          final filtered = allTickets.where((ticket) {
            bool statusMatch;
            switch (_filter) {
              case 'awaiting':
                statusMatch = ticket.status == 'verified';
                break;
              case 'onsite':
                statusMatch = ticket.status == 'pending_onsite' ||
                    ticket.status == 'in_progress';
                break;
              default:
                statusMatch = true;
            }

            final searchMatch = q.isEmpty ||
                ticket.id.toLowerCase().contains(q) ||
                ticket.productType.toLowerCase().contains(q) ||
                ticket.productIssue.toLowerCase().contains(q) ||
                ticket.siteName.toLowerCase().contains(q) ||
                ticket.createdByName.toLowerCase().contains(q);

            return statusMatch && searchMatch;
          }).toList();

          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: t.technicianSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                  ),
                ),
              ),
              FilterChipRow(
                selectedValue: _filter,
                onSelected: (v) => setState(() => _filter = v),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                options: [
                  FilterOption(
                    label: t.ttAwaitingYou,
                    value: 'awaiting',
                    count: awaitingCount,
                  ),
                  FilterOption(
                    label: t.adsbOnSite,
                    value: 'onsite',
                    count: onsiteCount,
                  ),
                  FilterOption(label: t.ttAll, value: 'all'),
                ],
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? EmptyState(
                  icon: Icons.check_circle_outline,
                  title: _filter == 'awaiting'
                      ? t.allCaughtUp
                      : t.ttNoTickets,
                  subtitle: _filter == 'awaiting'
                      ? t.ttNoAwaiting
                      : t.ttTryChangeFilter,
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _ticketCard(filtered[i], t),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ticketCard(Ticket ticket, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TechnicianReviewScreen(
                  ticketId: ticket.id,
                  user: widget.user,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.id,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    TTStatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ticket.productType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ticket.productIssue,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${ticket.siteName} · ${ticket.lanesSummary}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormatter.relative(ticket.updatedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}