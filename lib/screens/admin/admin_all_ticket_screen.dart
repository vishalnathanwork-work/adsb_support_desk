import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import '../client/ticket_detail_screen.dart';

class AdminAllTicketsScreen extends StatefulWidget {
  final UserModel user;

  const AdminAllTicketsScreen({super.key, required this.user});

  @override
  State<AdminAllTicketsScreen> createState() => _AdminAllTicketsScreenState();
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
      final statusMatch = _filterStatus == 'all' || t.status == _filterStatus;
      final searchMatch = q.isEmpty ||
          t.id.toLowerCase().contains(q) ||
          t.productType.toLowerCase().contains(q) ||
          t.createdByName.toLowerCase().contains(q);
      return statusMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tickets'),
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
                  decoration: const InputDecoration(
                    hintText: 'Search by ID, product, or client...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('All', 'all'),
                      _chip('Pending', 'pending'),
                      _chip('Verified', 'verified'),
                      _chip('In Progress', 'in_progress'),
                      _chip('Resolved', 'resolved'),
                      _chip('Closed', 'closed'),
                      _chip('Cancelled', 'cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.search_off,
              title: 'No tickets found',
              subtitle: 'Try changing your filters',
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final t = _filtered[i];
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(t.id,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary)),
                              ),
                              StatusBadge(status: t.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(t.productType,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(t.productIssue,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 8),

                          if (t.totalResolutionTime != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Resolved in ${Ticket.formatDuration(t.totalResolutionTime)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 12,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${t.createdByName} (${t.createdByRole})',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color:
                                      AppColors.textSecondary),
                                ),
                              ),
                              Text(DateFormatter.relative(t.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color:
                                      AppColors.textSecondary)),
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

  Widget _chip(String label, String value) {
    final selected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filterStatus = value;
            _applyFilter();
          });
        },
        selectedColor: AppColors.primary.withOpacity(0.15),
      ),
    );
  }
}
