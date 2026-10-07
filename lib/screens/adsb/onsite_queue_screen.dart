import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'onsite_job_screen.dart';

class OnsiteQueueScreen extends StatefulWidget {
  final UserModel user;

  const OnsiteQueueScreen({super.key, required this.user});

  @override
  State<OnsiteQueueScreen> createState() => _OnsiteQueueScreenState();
}

class _OnsiteQueueScreenState extends State<OnsiteQueueScreen> {
  final _service = TicketService();
  List<Ticket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // Load BOTH pending_onsite (unclaimed) and in_progress (claimed)
    final pendingOnsite = await _service.getPendingOnsiteTickets();
    final inProgress = await _service.getInProgressTickets();

    final combined = [...pendingOnsite, ...inProgress];
    combined.sort((a, b) {
      // Unclaimed first, then oldest first
      final aUnclaimed = a.status == 'pending_onsite';
      final bUnclaimed = b.status == 'pending_onsite';
      if (aUnclaimed != bUnclaimed) return aUnclaimed ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });

    if (!mounted) return;
    setState(() {
      _tickets = combined;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Site Queue'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
          ? const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No on-site jobs',
        subtitle: 'Assigned jobs will appear here',
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tickets.length,
          itemBuilder: (context, i) {
            final t = _tickets[i];
            return InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnsiteJobScreen(
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
                  border: Border.all(
                    color: t.status == 'pending_onsite'
                        ? AppColors.warning.withOpacity(0.4)
                        : AppColors.divider,
                    width: t.status == 'pending_onsite' ? 2 : 1,
                  ),
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
                            ),
                          ),
                        ),
                        if (t.status == 'pending_onsite')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            margin:
                            const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warning
                                  .withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'UNCLAIMED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
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
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.productIssue,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${t.siteName} — ${t.laneName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          DateFormatter.relative(t.updatedAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
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
    );
  }
}