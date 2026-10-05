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
    final list = await _service.getInProgressTickets();
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
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 8),
                    Text(t.productType,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(t.productIssue,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(t.siteName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ),
                        Text(DateFormatter.relative(t.updatedAt),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
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