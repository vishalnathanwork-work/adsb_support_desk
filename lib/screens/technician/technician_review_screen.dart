import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/tt_status_badge.dart';
import '../adsb/adsb_chat_screen.dart';

class TechnicianReviewScreen extends StatefulWidget {
  final String ticketId;
  final UserModel user;

  const TechnicianReviewScreen({
    super.key,
    required this.ticketId,
    required this.user,
  });

  @override
  State<TechnicianReviewScreen> createState() =>
      _TechnicianReviewScreenState();
}

class _TechnicianReviewScreenState extends State<TechnicianReviewScreen> {
  final _service = TicketService();
  Ticket? _ticket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ticket = await _service.getTicketById(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _ticket = ticket;
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

  Future<void> _callAdsbAgent() async {
    final l10n = AppLocalizations.of(context)!;
    const adsbPhone = '+60 12-345 6791';
    final uri = Uri.parse('tel:$adsbPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cannotCall('ADSB'))),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined),
            tooltip: t.callClient,
            onPressed: _callAdsbAgent,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _card(
              title: t.ticketDetails,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.statusLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TTStatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 12),
                _row(t.adminReportedBy, ticket.createdByName),
                _row(
                  t.contactLabel,
                  '${ticket.contactName} — ${ticket.contactPhone}',
                ),
                _row(t.siteLabel, ticket.siteName),
                _row(t.location, ticket.siteLocation),
                _row(
                  t.parkingLabel,
                  '${ticket.laneName} (${ticket.laneDirectionDisplay})',
                ),
                _row(t.adminProductLabel, ticket.productType),
                if (ticket.productIssue.isNotEmpty)
                  _row(t.adminIssueLabel, ticket.productIssue),
                if (ticket.description.isNotEmpty)
                  _row(t.descriptionLabel, ticket.description),
                _row(
                  t.reportedLabel,
                  DateFormatter.full(ticket.createdAt),
                ),

                if (ticket.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    t.reportedPhotos,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: ticket.imageUrls,
                    title: t.reportedPhotos,
                  ),
                ],

                if (ticket.completionImageUrl != null &&
                    ticket.completionImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    t.completionEvidence,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: [ticket.completionImageUrl!],
                    title: t.completionEvidence,
                  ),
                ],
              ],
            ),

            if (ticket.escalationReason != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _card(
                title: t.descriptionLabel,
                children: [
                  Text(
                    ticket.escalationReason!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (ticket.assignedToName != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.escalatedBy(ticket.assignedToName!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _openChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 22),
                label: Text(
                  t.openChat,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                t.technicianAdviceHint,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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