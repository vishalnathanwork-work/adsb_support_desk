import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatusHelper {
  static String label(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'reopened':
        return 'Reopened';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'verified':
        return AppColors.accent;
      case 'in_progress':
        return AppColors.primary;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.textSecondary;
      case 'reopened':
        return AppColors.error;
      case 'cancelled':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }
}