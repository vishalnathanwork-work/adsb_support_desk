import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import '../../utils/date_formatter.dart';
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
    final pendingCount =
        _tickets.where((t) => t.status == 'pending').length;
    final withTtCount =
        _tickets.where((t) => t.status == 'verified').length;
    final onsiteCount = _tickets
        .where((t) =>
    t.status == 'pending_onsite' || t.status == 'in_progress')
        .length;

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
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All Active', 'active', null),
                  const SizedBox(width: 8),
                  _filterChip('Pending', 'pending', pendingCount),
                  const SizedBox(width: 8),
                  _filterChip('With TT', 'with_tt', withTtCount),
                  const SizedBox(width: 8),
                  _filterChip('On-Site', 'onsite', onsiteCount),
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
              title: 'All caught up!',
              subtitle: 'No tickets in the queue',
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

  Widget _filterChip(String label, String value, int? count) {
    final selected = _filter == value;
    final display = count == null ? label : '$label ($count)';

    return ChoiceChip(
      label: Text(display, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primary.withOpacity(0.15),
    );
  }

  Widget _ticketTile(Ticket t) {
    final isWithTT = t.status == 'verified';
    final isOnsite = t.status == 'pending_onsite' || t.status == 'in_progress';
    final isResolved = t.status == 'resolved';
    final isPending = t.status == 'pending';

    Color borderColor;
    if (isWithTT) {
      borderColor = const Color(0xFF5E35B1).withOpacity(0.4);
    } else if (isOnsite) {
      borderColor = AppColors.primary.withOpacity(0.4);
    } else if (isResolved) {
      borderColor = AppColors.success.withOpacity(0.4);
    } else {
      borderColor = AppColors.divider;
    }

    return InkWell(
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isWithTT || isOnsite || isResolved ? 2 : 1,
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
                if (isWithTT)
                  _badge('WITH TT', const Color(0xFF5E35B1))
                else if (isOnsite)
                  _badge('ON-SITE', AppColors.primary)
                else if (isResolved)
                    _badge('RESOLVED', AppColors.success),
                const SizedBox(width: 6),
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
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${t.createdByName} · ${t.siteName} — ${t.laneName}',
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}