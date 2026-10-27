import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/status_badge.dart';
import 'adsb_ticket_action_screen.dart';

class AdsbQueueScreen extends StatefulWidget {
  final UserModel user;

  const AdsbQueueScreen({super.key, required this.user});

  @override
  State<AdsbQueueScreen> createState() => _AdsbQueueScreenState();
}

class _AdsbQueueScreenState extends State<AdsbQueueScreen> {
  final _service = TicketService();
  String _filter = 'active';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;   // ← moved UP

    return Scaffold(
      appBar: AppBar(title: Text(t.adsbQueue)),   // ← removed const
      body: StreamBuilder<List<Ticket>>(
        stream: _service.streamActiveTicketsForAdsb(),
        builder: (context, snapshot) {
          final allTickets = snapshot.data ?? [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

          final pendingCount =
              allTickets.where((ticket) => ticket.status == 'pending').length;
          final withTtCount =
              allTickets.where((ticket) => ticket.status == 'verified').length;
          final onsiteCount = allTickets
              .where((ticket) =>
          ticket.status == 'pending_onsite' ||
              ticket.status == 'in_progress')
              .length;

          final filtered = switch (_filter) {
            'pending' =>
                allTickets.where((ticket) => ticket.status == 'pending').toList(),
            'with_tt' =>
                allTickets.where((ticket) => ticket.status == 'verified').toList(),
            'onsite' => allTickets
                .where((ticket) =>
            ticket.status == 'pending_onsite' ||
                ticket.status == 'in_progress')
                .toList(),
            _ => allTickets,
          };

          return Column(
            children: [
              FilterChipRow(
                selectedValue: _filter,
                onSelected: (v) => setState(() => _filter = v),
                options: [
                  FilterOption(
                    label: t.adsbAllActive,   // ← removed const
                    value: 'active',
                  ),
                  FilterOption(
                    label: t.adsbPending,
                    value: 'pending',
                    count: pendingCount,
                  ),
                  FilterOption(
                    label: t.adsbWithTt,
                    value: 'with_tt',
                    count: withTtCount,
                  ),
                  FilterOption(
                    label: t.adsbOnSite,
                    value: 'onsite',
                    count: onsiteCount,
                  ),
                ],
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? EmptyState(
                  icon: Icons.check_circle_outline,
                  title: t.allCaughtUp,        // ← removed const
                  subtitle: t.noTicketsInView, // ← removed const
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _ticketTile(filtered[i], t),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ticketTile(Ticket ticket, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdsbTicketActionScreen(
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
                    StatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ticket.productType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
                      Icons.person_outline,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${ticket.createdByName} · ${ticket.siteName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.relative(ticket.createdAt),
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