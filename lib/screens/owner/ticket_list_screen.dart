import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/ticket_card.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class TicketListScreen extends StatefulWidget {
  final UserModel user;
  final bool showAppBar;

  const TicketListScreen({
    super.key,
    required this.user,
    this.showAppBar = true,
  });

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final _service = TicketService();

  String _filter = 'active';

  Future<void> _openCreate() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTicketScreen(user: widget.user),
      ),
    );
    // No reload — the stream handles new tickets.
  }

  @override
  Widget build(BuildContext context) {
    // ─── No sites case ───
    if (widget.user.siteIds.isEmpty) {
      final empty = const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'No sites assigned',
        subtitle: 'Contact admin',
      );

      if (!widget.showAppBar) return empty;

      return Scaffold(
        appBar: AppBar(title: const Text('Tickets')),
        body: empty,
      );
    }

    // ─── Live list ───
    final body = StreamBuilder<List<Ticket>>(
      stream: _service.streamActiveTicketsForSites(widget.user.siteIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load tickets',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final tickets = snapshot.data ?? [];

        final activeTickets = tickets
            .where((t) => t.status != 'closed' && t.status != 'cancelled')
            .toList();

        final filtered = _filter == 'active' ? activeTickets : tickets;

        if (tickets.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No tickets yet',
            subtitle: 'Tap + to create a new ticket',
          );
        }

        return Column(
          children: [
            FilterChipRow(
              selectedValue: _filter,
              onSelected: (v) => setState(() => _filter = v),
              options: [
                FilterOption(
                  label: 'Active',
                  value: 'active',
                  count: activeTickets.length,
                ),
                FilterOption(
                  label: 'All',
                  value: 'all',
                  count: tickets.length,
                ),
              ],
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No active tickets',
                      subtitle: 'Switch to "All" to see closed tickets',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => TicketCard(
                        ticket: filtered[i],
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TicketDetailScreen(
                                ticketId: filtered[i].id,
                                user: widget.user,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Tickets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
      body: body,
    );
  }
}