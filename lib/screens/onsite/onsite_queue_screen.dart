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
  String _filter = 'unclaimed';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final pendingOnsite = await _service.getPendingOnsiteTickets();
    final inProgress = await _service.getInProgressTickets();

    final combined = [...pendingOnsite, ...inProgress];
    combined.sort((a, b) {
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

  List<Ticket> get _filtered {
    switch (_filter) {
      case 'unclaimed':
        return _tickets.where((t) => t.status == 'pending_onsite').toList();
      case 'mine':
        return _tickets
            .where((t) =>
        t.status == 'in_progress' &&
            t.assignedTo == widget.user.email)
            .toList();
      case 'all':
      default:
        return _tickets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unclaimedCount =
        _tickets.where((t) => t.status == 'pending_onsite').length;
    final mineCount = _tickets
        .where((t) =>
    t.status == 'in_progress' && t.assignedTo == widget.user.email)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Site Jobs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                      'Unclaimed ($unclaimedCount)', 'unclaimed'),
                  const SizedBox(width: 8),
                  _filterChip('My Jobs ($mineCount)', 'mine'),
                  const SizedBox(width: 8),
                  _filterChip('All', 'all'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No jobs here',
              subtitle: 'Jobs will appear once assigned',
            )
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
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

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primary.withOpacity(0.15),
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
                if (isUnclaimed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'UNCLAIMED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  )
                else if (isMine)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
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