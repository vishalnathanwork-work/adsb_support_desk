import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
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
  List<Ticket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _service.getVerifiedTickets();
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: const Color(0xFF5E35B1),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
          ? const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No pending reviews',
        subtitle:
        'Tickets escalated by ADSB will appear here.',
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tickets.length,
          itemBuilder: (context, i) => _ticketCard(_tickets[i]),
        ),
      ),
    );
  }

  Widget _ticketCard(Ticket t) {
    return InkWell(
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF5E35B1).withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: ID + status ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.id,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E35B1),
                    ),
                  ),
                ),
                StatusBadge(status: t.status),
              ],
            ),
            const SizedBox(height: 10),

            // ── Product + issue ──
            Row(
              children: [
                const Icon(
                  Icons.build_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.productType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                t.productIssue,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Site + parking ──
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
                    '${t.siteName} — ${t.laneName} (${t.laneDirectionDisplay})',
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

            // ── Escalation banner ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_upward,
                    size: 12,
                    color: Color(0xFF5E35B1),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Escalated by ${t.assignedToName ?? "ADSB Support"}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E35B1),
                      ),
                    ),
                  ),
                  Text(
                    DateFormatter.relative(t.updatedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}