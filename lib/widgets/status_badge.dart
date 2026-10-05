import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (String, Color) _style() {
    switch (status) {
      case 'pending':
        return ('Pending', AppColors.warning);
      case 'verified':
        return ('Verified', AppColors.accent);
      case 'in_progress':
        return ('In Progress', AppColors.primary);
      case 'resolved':
        return ('Resolved', AppColors.success);
      case 'closed':
        return ('Closed', AppColors.textSecondary);
      case 'reopened':
        return ('Reopened', AppColors.error);
      case 'cancelled':
        return ('Cancelled', AppColors.textSecondary);
      default:
        return (status, AppColors.textSecondary);
    }
  }
}