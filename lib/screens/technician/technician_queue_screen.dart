import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import 'technician_review_screen.dart';
import '../../widgets/tt_status_badge.dart';


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
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: StreamBuilder<List<Ticket>>(
        stream: _service.streamTTQueueTickets(),
        builder: (context, snapshot) {
          final allTickets = snapshot.data ?? [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

          final awaitingCount =
              allTickets.where((t) => t.status == 'verified').length;
          final onsiteCount = allTickets
              .where((t) =>
          t.status == 'pending_onsite' ||
              t.status == 'in_progress')
              .length;

          final q = _searchController.text.trim().toLowerCase();

          final filtered = allTickets.where((t) {
            bool statusMatch;
            switch (_filter) {
              case 'awaiting':
                statusMatch = t.status == 'verified';
                break;
              case 'onsite':
                statusMatch = t.status == 'pending_onsite' ||
                    t.status == 'in_progress';
                break;
              default:
                statusMatch = true;
            }

            final searchMatch = q.isEmpty ||
                t.id.toLowerCase().contains(q) ||
                t.productType.toLowerCase().contains(q) ||
                t.productIssue.toLowerCase().contains(q) ||
                t.siteName.toLowerCase().contains(q) ||
                t.createdByName.toLowerCase().contains(q);

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
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search),
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
                    label: 'Awaiting You',
                    value: 'awaiting',
                    count: awaitingCount,
                  ),
                  FilterOption(
                    label: 'On-Site',
                    value: 'onsite',
                    count: onsiteCount,
                  ),
                  const FilterOption(label: 'All', value: 'all'),
                ],
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? EmptyState(
                  icon: Icons.check_circle_outline,
                  title: _filter == 'awaiting'
                      ? 'All caught up!'
                      : 'No tickets found',
                  subtitle: _filter == 'awaiting'
                      ? 'No tickets awaiting your review'
                      : 'Try changing your filter',
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
                      _ticketCard(filtered[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ticketCard(Ticket t) {
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
                  ticketId: t.id,
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
                        t.id,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    TTStatusBadge(status: t.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  t.productType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.productIssue,
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
                        '${t.siteName} · ${t.lanesSummary}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormatter.relative(t.updatedAt),
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