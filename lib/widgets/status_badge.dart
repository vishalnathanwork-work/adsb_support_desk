import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final (label, fg, bg) = _style(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  (String, Color, Color) _style(AppLocalizations t) {
    switch (status) {
      case 'pending':
        return (
        t.statusPendingLabel,
        AppColors.warning,
        AppColors.warningLight,
        );
      case 'verified':
        return (
        t.statusVerifiedLabel,
        AppColors.info,
        AppColors.infoLight,
        );
      case 'pending_onsite':
        return (
        t.statusPendingOnsiteLabel,
        AppColors.primary,
        const Color(0xFFDBEAFE),
        );
      case 'in_progress':
        return (
        t.statusInProgressLabel,
        AppColors.primary,
        const Color(0xFFDBEAFE),
        );
      case 'resolved':
        return (
        t.statusResolvedLabel,
        AppColors.success,
        AppColors.successLight,
        );
      case 'closed':
        return (
        t.statusClosedLabel,
        AppColors.textSecondary,
        AppColors.surfaceAlt,
        );
      case 'reopened':
        return (
        t.statusReopenedLabel,
        AppColors.error,
        AppColors.errorLight,
        );
      case 'cancelled':
        return (
        t.statusCancelledLabel,
        AppColors.textSecondary,
        AppColors.surfaceAlt,
        );
      default:
        return (status, AppColors.textSecondary, AppColors.surfaceAlt);
    }
  }
}