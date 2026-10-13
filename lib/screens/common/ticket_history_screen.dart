import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/status_badge.dart';
import '../owner/ticket_detail_screen.dart';

/// Generic ticket history screen for any role.
/// Pass in a loader that returns the tickets this user should see.
class TicketHistoryScreen extends StatefulWidget {
  final UserModel user;
  final Future<List<Ticket>> Function() loader;
  final String title;

  const TicketHistoryScreen({
    super.key,
    required this.user,
    required this.loader,
    this.title = 'History',
  });

  @override
  State<TicketHistoryScreen> createState() => _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends State<TicketHistoryScreen> {
  List<Ticket> _all = [];
  List<Ticket> _filtered = [];
  bool _isLoading = true;
  String _filter = 'all';
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
    final list = await widget.loader();
    if (!mounted) return;
    setState(() {
      _all = list;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    _filtered = _all.where((t) {
      // Status filter
      bool statusMatch = true;
      switch (_filter) {
        case 'open':
          statusMatch = t.isActive;
          break;
        case 'closed':
          statusMatch = t.status == 'closed' || t.status == 'resolved';
          break;
        case 'cancelled':
          statusMatch = t.status == 'cancelled';
          break;
      }

      // Search filter
      final searchMatch = q.isEmpty ||
          t.id.toLowerCase().contains(q) ||
          t.productType.toLowerCase().contains(q) ||
          t.productIssue.toLowerCase().contains(q) ||
          t.siteName.toLowerCase().contains(q) ||
          t.createdByName.toLowerCase().contains(q);

      return statusMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
                  onChanged: (_) => setState(_applyFilters),
                  decoration: const InputDecoration(
                    hintText: 'Search by ID, product, site, or client...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                FilterChipRow(
                  selectedValue: _filter,
                  onSelected: (v) {
                    setState(() {
                      _filter = v;
                      _applyFilters();
                    });
                  },
                  options: const [
                    FilterOption(label: 'All', value: 'all'),
                    FilterOption(label: 'Open', value: 'open'),
                    FilterOption(label: 'Closed', value: 'closed'),
                    FilterOption(label: 'Cancelled', value: 'cancelled'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.history,
              title: 'No tickets found',
              subtitle: 'Try changing your filters',
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
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
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketDetailScreen(
              ticketId: t.id,
              user: widget.user,
            ),
          ),
        );
        _load();
      },
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                StatusBadge(status: t.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.productType,
              style: const TextStyle(
                fontSize: 14,
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${t.siteName} · ${t.laneName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormatter.relative(t.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}