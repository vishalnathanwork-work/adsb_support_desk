import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/status_badge.dart';
import 'technician_review_screen.dart';

class TechnicianQueueScreen extends StatefulWidget {
  final UserModel user;

  const TechnicianQueueScreen({super.key, required this.user});

  @override
  State<TechnicianQueueScreen> createState() => _TechnicianQueueScreenState();
}

class _TechnicianQueueScreenState extends State<TechnicianQueueScreen> {
  final _service = TicketService();

  List<Ticket> _all = [];
  List<Ticket> _filtered = [];
  bool _isLoading = true;
  String _filter = 'awaiting';
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
    final list = await _service.getTTQueueTickets();
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
      bool statusMatch = true;
      switch (_filter) {
        case 'awaiting':
          statusMatch = t.status == 'verified';
          break;
        case 'onsite':
          statusMatch =
              t.status == 'pending_onsite' || t.status == 'in_progress';
          break;
        case 'all':
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
  }

  // ─── Counts ───
  int get _awaitingCount =>
      _all.where((t) => t.status == 'verified').length;

  int get _onsiteCount => _all
      .where((t) =>
  t.status == 'pending_onsite' || t.status == 'in_progress')
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search ───
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
              onChanged: (_) => setState(_applyFilter),
              decoration: const InputDecoration(
                hintText: 'Search by ID, product, or site...',
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),

          // ─── Filter chips ───
          FilterChipRow(
            selectedValue: _filter,
            onSelected: (v) {
              setState(() {
                _filter = v;
                _applyFilter();
              });
            },
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
                count: _awaitingCount,
              ),
              FilterOption(
                label: 'On-Site',
                value: 'onsite',
                count: _onsiteCount,
              ),
              const FilterOption(label: 'All', value: 'all'),
            ],
          ),

          // ─── List ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? EmptyState(
              icon: Icons.check_circle_outline,
              title: _filter == 'awaiting'
                  ? 'All caught up!'
                  : 'No tickets found',
              subtitle: _filter == 'awaiting'
                  ? 'No tickets awaiting your review'
                  : 'Try changing your filter',
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                itemCount: _filtered.length,
                itemBuilder: (context, i) =>
                    _ticketCard(_filtered[i]),
              ),
            ),
          ),
        ],
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
                // ─── ID + Status (single badge) ───
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

                // ─── Product + Issue ───
                Row(
                  children: [
                    const Icon(
                      Icons.build_outlined,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.productType,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 21),
                  child: Text(
                    t.productIssue,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Location ───
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
                        '${t.siteName} · ${t.laneName} (${t.laneDirectionDisplay})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ─── Reporter + Time ───
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
                        'Reported by ${t.createdByName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
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