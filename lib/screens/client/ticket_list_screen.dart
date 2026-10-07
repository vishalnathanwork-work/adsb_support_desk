import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ticket_card.dart';
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
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _service.getMyTickets(widget.user.email);
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _isLoading = false;
    });
  }

  List<Ticket> get _filtered {
    switch (_filter) {
      case 'active':
        return _tickets.where((t) => t.isActive).toList();
      case 'resolved':
        return _tickets.where((t) => t.isResolved).toList();
      case 'cancelled':
        return _tickets.where((t) => t.status == 'cancelled').toList();
      default:
        return _tickets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _tickets.isEmpty
        ? EmptyState(
      icon: Icons.inbox_outlined,
      title: 'No tickets yet',
      subtitle: 'Create a new ticket to get started',
    )
        : Column(
      children: [
        _buildFilterRow(),
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
                    _load(); // refresh after return
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
      appBar: AppBar(title: const Text('My Tickets')),
      body: body,
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('All', 'all'),
            const SizedBox(width: 8),
            _filterChip('Active', 'active'),
            const SizedBox(width: 8),
            _filterChip('Resolved', 'resolved'),
            const SizedBox(width: 8),
            _filterChip('Cancelled', 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }
}