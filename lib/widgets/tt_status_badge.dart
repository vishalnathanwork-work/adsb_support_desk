import 'package:flutter/material.dart';
import '../config/theme.dart';

/// TT-friendly status badge.
/// Simplifies the 8-status ticket lifecycle into 4 labels that
/// matter for an advisor: Pending / On-Site / Solved / Cancelled.
class TTStatusBadge extends StatelessWidget {
  final String status;

  const TTStatusBadge({super.key, required this.status});

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
    // Pending (new, awaiting advice)
      case 'pending':
      case 'verified':
        return ('Needs Advice', AppColors.warning, AppColors.warningLight);

    // On-site (ADSB is handling it)
      case 'pending_onsite':
      case 'in_progress':
        return ('On-Site', AppColors.info, AppColors.infoLight);

    // Solved
      case 'resolved':
      case 'closed':
        return ('Solved', AppColors.success, AppColors.successLight);

    // Reopened — needs attention again
      case 'reopened':
        return ('Reopened', AppColors.error, AppColors.errorLight);

    // Cancelled
      case 'cancelled':
        return ('Cancelled', AppColors.textSecondary, AppColors.surfaceAlt);

      default:
        return (status, AppColors.textSecondary, AppColors.surfaceAlt);
    }
  }
}