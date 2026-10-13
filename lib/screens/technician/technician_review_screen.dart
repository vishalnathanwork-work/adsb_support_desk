import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';
import '../../services/ticket_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/status_badge.dart';
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

  Future<void> _callAdsbAgent() async {
    const adsbPhone = '+60 12-345 6791';
    final uri = Uri.parse('tel:$adsbPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot call ADSB agent')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ticket')),
        body: const Center(child: Text('Ticket not found')),
      );
    }

    final t = _ticket!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined),
            tooltip: 'Call ADSB agent',
            onPressed: _callAdsbAgent,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ─── Ticket Details ───
            _card(
              title: 'Ticket Details',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    StatusBadge(status: t.status),
                  ],
                ),
                const SizedBox(height: 12),
                _row('Reported by', t.createdByName),
                _row('Contact', '${t.contactName} — ${t.contactPhone}'),
                _row('Site', t.siteName),
                _row('Location', t.siteLocation),
                _row(
                  'Parking',
                  '${t.laneName} (${t.laneDirectionDisplay})',
                ),
                _row('Product', t.productType),
                if (t.productIssue.isNotEmpty)
                  _row('Issue', t.productIssue),
                if (t.description.isNotEmpty)
                  _row('Description', t.description),
                _row('Reported at', DateFormatter.full(t.createdAt)),

                // ─── Reported photos ───
                if (t.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Reported Photos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: t.imageUrls,
                    title: 'Reported Photos',
                  ),
                ],

                // ─── Completion evidence ───
                if (t.completionImageUrl != null &&
                    t.completionImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Completion Evidence',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageGallery(
                    urls: [t.completionImageUrl!],
                    title: 'Completion Evidence',
                  ),
                ],
              ],
            ),

            // ─── Escalation reason ───
            if (t.escalationReason != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _card(
                title: 'Reason for Escalation',
                children: [
                  Text(
                    t.escalationReason!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (t.assignedToName != null) ...[
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
                          'Escalated by ${t.assignedToName}',
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

            // ─── Chat ───
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _openChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 22),
                label: const Text(
                  'Open Chat',
                  style: TextStyle(
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

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Provide your advice directly in the chat. '
                    'The ADSB team will act on it and update the client.',
                style: TextStyle(
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