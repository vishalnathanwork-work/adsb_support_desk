import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = _style();
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

  (String, Color, Color) _style() {
    switch (status) {
      case 'pending':
        return ('Pending', AppColors.warning, AppColors.warningLight);
      case 'verified':
        return ('In Review', AppColors.info, AppColors.infoLight);
      case 'pending_onsite':
        return ('On-Site Queued', AppColors.primary, const Color(0xFFDBEAFE));
      case 'in_progress':
        return ('In Progress', AppColors.primary, const Color(0xFFDBEAFE));
      case 'resolved':
        return ('Resolved', AppColors.success, AppColors.successLight);
      case 'closed':
        return ('Closed', AppColors.textSecondary, AppColors.surfaceAlt);
      case 'reopened':
        return ('Reopened', AppColors.error, AppColors.errorLight);
      case 'cancelled':
        return ('Cancelled', AppColors.textSecondary, AppColors.surfaceAlt);
      default:
        return (status, AppColors.textSecondary, AppColors.surfaceAlt);
    }
  }
}