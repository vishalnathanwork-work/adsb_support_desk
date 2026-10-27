import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/status_badge.dart';
import '../adsb/adsb_chat_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.user,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _service = TicketService();
  Ticket? _ticket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _service.getTicketById(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _ticket = t;
      _isLoading = false;
    });
  }

  Future<void> _openChat() async {
    if (_ticket == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdsbChatScreen(
          ticketId: _ticket!.id,
          user: widget.user,
        ),
      ),
    );
    _load();
  }

  Future<void> _confirmResolution() async {
    final t = AppLocalizations.of(context)!;
    await _service.confirmResolution(widget.ticketId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.ticketClosedThanks),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _reopen() async {
    final t = AppLocalizations.of(context)!;
    await _service.reopenTicket(widget.ticketId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.ticketReopened),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Future<void> _cancel() async {
    final t = AppLocalizations.of(context)!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.cancelTicketTitle),
        content: Text(t.cancelTicketMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.yesCancel),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _service.cancelTicket(widget.ticketId);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ticket == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.ticketsTitle)),
        body: Center(child: Text(t.ticketNotFound)),
      );
    }

    final ticket = _ticket!;
    final canChat = ticket.status != 'closed' &&
        ticket.status != 'cancelled';
    final isResolved = ticket.status == 'resolved';

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.id),
        actions: [
          if (ticket.isActive)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _cancel,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
                        child: Text(
                          ticket.productType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusBadge(status: ticket.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.productIssue,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket.statusDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (canChat) ...[
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    t.openChat,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _section(t.ticketDetails),
            _infoTile(t.siteLabel,
                '${ticket.siteName} — ${ticket.siteLocation}'),
            _infoTile(t.parkingLabel,
                '${ticket.laneName} (${ticket.laneDirectionDisplay})'),
            _infoTile(t.contactLabel,
                '${ticket.contactName} (${ticket.contactPhone})'),
            _infoTile(t.reportedLabel,
                DateFormatter.full(ticket.createdAt)),
            if (ticket.description.isNotEmpty)
              _infoTile(t.descriptionLabel, ticket.description),

            if (ticket.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section(t.reportedPhotos),
              const SizedBox(height: 8),
              ImageGallery(
                urls: ticket.imageUrls,
                title: t.reportedPhotos,
              ),
            ],

            if (ticket.completionImageUrl != null &&
                ticket.completionImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section(t.completionEvidence),
              const SizedBox(height: 8),
              ImageGallery(
                urls: [ticket.completionImageUrl!],
                title: t.completionEvidence,
              ),
            ],

            const SizedBox(height: 16),

            if (ticket.resolvedAt != null) ...[
              _section(t.resolution),
              _infoTile(t.rootCause, ticket.rootCause ?? '—'),
              _infoTile(t.solution, ticket.solutionApplied ?? '—'),
              if (ticket.resolutionNotes != null &&
                  ticket.resolutionNotes!.isNotEmpty)
                _infoTile(t.notes, ticket.resolutionNotes!),
              _infoTile(t.resolvedAt,
                  DateFormatter.full(ticket.resolvedAt!)),
              const SizedBox(height: 16),
            ],

            if (isResolved) ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _confirmResolution,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(t.confirmResolution),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _reopen,
                  icon: const Icon(Icons.refresh),
                  label: Text(t.reopenTicket),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}