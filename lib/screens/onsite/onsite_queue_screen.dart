import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/status_badge.dart';
import 'onsite_job_screen.dart';
import '../adsb/adsb_chat_screen.dart';

class OnsiteQueueScreen extends StatefulWidget {
  final UserModel user;

  const OnsiteQueueScreen({super.key, required this.user});

  @override
  State<OnsiteQueueScreen> createState() => _OnsiteQueueScreenState();
}

class _OnsiteQueueScreenState extends State<OnsiteQueueScreen> {
  final _service = TicketService();
  String _filter = 'unclaimed';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On-Site Jobs')),
      body: StreamBuilder<List<Ticket>>(
        stream: _service.streamOnsiteQueue(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final all = snapshot.data ?? [];
          final unclaimed = all.where((t) => t.status == 'pending_onsite').toList();
          final mine = all
              .where((t) => t.status == 'in_progress' && t.assignedTo == widget.user.email)
              .toList();

          final filtered = switch (_filter) {
            'unclaimed' => unclaimed,
            'mine' => mine,
            _ => all,
          };

          return Column(
            children: [
              // Filter chips
              FilterChipRow(
                selectedValue: _filter,
                onSelected: (v) => setState(() => _filter = v),
                options: [
                  FilterOption(label: 'Unclaimed', value: 'unclaimed', count: unclaimed.length),
                  FilterOption(label: 'My Jobs', value: 'mine', count: mine.length),
                  const FilterOption(label: 'All', value: 'all'),
                ],
              ),

              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No jobs here',
                  subtitle: 'Jobs will appear here in real time',
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _ticketTile(filtered[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ticketTile(Ticket t) {
    final isUnclaimed = t.status == 'pending_onsite';
    final isMine = t.assignedTo == widget.user.email;

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
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnclaimed
                ? AppColors.warning.withOpacity(0.5)
                : AppColors.primary.withOpacity(0.5),
            width: 2,
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
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondary),
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
  }
}