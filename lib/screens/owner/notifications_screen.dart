import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../admin/admin_users_screen.dart';
import '../adsb/adsb_chat_screen.dart';
import 'ticket_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final UserModel user;

  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  String _filter = 'all';

  Future<void> _open(AppNotification n) async {
    await _service.markAsRead(n.id);
    if (!mounted) return;

    // 1. Registration → User Management (admin)
    if (n.type == 'user_registration') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminUsersScreen(user: widget.user),
        ),
      );
      return;
    }

    // 2. Empty ticket (approval/rejection) → nothing
    if (n.ticketId.isEmpty) return;

    // 3. Chat message → open chat directly
    if (n.type == 'chat_message') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdsbChatScreen(
            ticketId: n.ticketId,
            user: widget.user,
          ),
        ),
      );
      return;
    }

    // 4. Everything else → ticket detail
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(
          ticketId: n.ticketId,
          user: widget.user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.notificationsTitle)),
      body: StreamBuilder<List<AppNotification>>(
        stream: _service.streamMyNotifications(widget.user.email),
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
                    Text(
                      t.notificationsError,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          final all = snapshot.data ?? [];

          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none,
              title: t.notificationsEmpty,
              subtitle: t.notificationsEmptyHint,
            );
          }

          final filtered = _applyFilter(all);

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(t.notificationsTabAll, 'all', all.length),
                      const SizedBox(width: 8),
                      _chip(
                        t.notificationsTabTickets,
                        'ticket',
                        _applyFilter(all, target: 'ticket').length,
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        t.notificationsTabAssignments,
                        'assignment',
                        _applyFilter(all, target: 'assignment').length,
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        t.notificationsTabAccount,
                        'user',
                        _applyFilter(all, target: 'user').length,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.inbox_outlined,
                        title: t.notificationsNoneInCategory,
                        subtitle: t.notificationsTryDifferent,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _notificationTile(filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<AppNotification> _applyFilter(
      List<AppNotification> all, {
        String? target,
      }) {
    final f = target ?? _filter;
    switch (f) {
      case 'ticket':
        return all
            .where((n) =>
        n.type == 'status_update' ||
            n.type == 'schedule' ||
            n.type == 'resolved' ||
            n.type == 'chat_message')
            .toList();
      case 'assignment':
        return all.where((n) => n.type == 'assignment').toList();
      case 'user':
        return all
            .where((n) =>
        n.type == 'user_registration' ||
            n.type == 'user_approved' ||
            n.type == 'user_rejected')
            .toList();
      default:
        return all;
    }
  }

  Widget _chip(String label, String value, int count) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          count > 0 ? '$label ($count)' : label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _notificationTile(AppNotification n) {
    return InkWell(
      onTap: () => _open(n),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead
              ? Colors.white
              : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForType(n.type),
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                      n.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormatter.relative(n.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'assignment':
        return Icons.person_add_alt;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'schedule':
        return Icons.event_available_outlined;
      case 'user_registration':
        return Icons.person_add_outlined;
      case 'user_approved':
        return Icons.verified_user_outlined;
      case 'user_rejected':
        return Icons.block_outlined;
      case 'status_update':
      default:
        return Icons.notifications_outlined;
    }
  }
}