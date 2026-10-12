import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../widgets/empty_state.dart';
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

    List<Ticket> list;

    // Owner / operator see every active ticket at their sites.
    if ((widget.user.isOwner || widget.user.isOperator) &&
        widget.user.siteIds.isNotEmpty) {
      list = await _service.getActiveTicketsForSites(widget.user.siteIds);
    } else {
      // Fallback for other roles.
      list = await _service.getMyTickets(widget.user.email);
    }

    if (!mounted) return;
    setState(() {
      _tickets = list;
      _isLoading = false;
    });
  }

  List<Ticket> get _filtered {
    switch (_filter) {
      case 'all':
        return _tickets;
      case 'active':
      default:
        return _tickets
            .where((t) =>
        t.status != 'closed' && t.status != 'cancelled')
            .toList();
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTicketScreen(user: widget.user),
      ),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _tickets
        .where((t) => t.status != 'closed' && t.status != 'cancelled')
        .length;

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _tickets.isEmpty
        ? const EmptyState(
      icon: Icons.inbox_outlined,
      title: 'No tickets yet',
      subtitle: 'Tap + to create a new ticket',
    )
        : Column(
      children: [
        _buildFilterRow(activeCount),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final ticket = _filtered[i];
                return TicketCard(
                  ticket: ticket,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketDetailScreen(
                          ticketId: ticket.id,
                          user: widget.user,
                        ),
                      ),
                    );
                    _load();
                  },
                );
              },
            ),
          ),
        ),
      ],
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

  Widget _buildFilterRow(int activeCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          _filterChip('Active ($activeCount)', 'active'),
          const SizedBox(width: 8),
          _filterChip('All', 'all'),
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
}