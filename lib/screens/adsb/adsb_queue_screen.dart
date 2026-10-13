import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
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
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _service.getActiveTickets();
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _isLoading = false;
    });
  }

  // ─── Counts ───
  int get _pendingCount =>
      _tickets.where((t) => t.status == 'pending').length;

  int get _withTtCount =>
      _tickets.where((t) => t.status == 'verified').length;

  int get _onsiteCount => _tickets
      .where((t) =>
  t.status == 'pending_onsite' || t.status == 'in_progress')
      .length;

  // ─── Filtered list ───
  List<Ticket> get _filtered {
    switch (_filter) {
      case 'pending':
        return _tickets.where((t) => t.status == 'pending').toList();
      case 'with_tt':
        return _tickets.where((t) => t.status == 'verified').toList();
      case 'onsite':
        return _tickets
            .where((t) =>
        t.status == 'pending_onsite' ||
            t.status == 'in_progress')
            .toList();
      case 'active':
      default:
        return _tickets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter chips ───
          FilterChipRow(
            selectedValue: _filter,
            onSelected: (v) => setState(() => _filter = v),
            options: [
              const FilterOption(label: 'All Active', value: 'active'),
              FilterOption(
                label: 'Pending',
                value: 'pending',
                count: _pendingCount,
              ),
              FilterOption(
                label: 'With TT',
                value: 'with_tt',
                count: _withTtCount,
              ),
              FilterOption(
                label: 'On-Site',
                value: 'onsite',
                count: _onsiteCount,
              ),
            ],
          ),

          // ─── List ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All caught up!',
              subtitle: 'No tickets in this view',
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _filtered.length,
                itemBuilder: (context, i) =>
                    _ticketTile(_filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketTile(Ticket t) {
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
                  ticketId: t.id,
                  user: widget.user,
                ),
              ),
            );
            _load();
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
                // ─── ID + Status (SINGLE badge) ───
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
                    StatusBadge(status: t.status),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Product + issue ───
                Text(
                  t.productType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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

                // ─── Reporter + location + time ───
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
                        '${t.createdByName} · ${t.siteName} · ${t.laneName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.relative(t.createdAt),
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