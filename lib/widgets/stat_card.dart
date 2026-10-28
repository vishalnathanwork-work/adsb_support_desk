import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Visual variants for `StatCard`.
enum StatCardVariant {
  blue,    // open tickets, active work
  green,   // completed, resolved, positive
  gray,    // neutral info
  warning, // warnings, conflicts
  error,   // errors, rejected, cancelled
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color color;                       // icon + value colour
  final StatCardVariant variant;           // background tint
  final VoidCallback? onTap;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    required this.color,
    this.variant = StatCardVariant.blue,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border) = _surface();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (Color bg, Color border) _surface() {
    switch (variant) {
      case StatCardVariant.blue:
        return (AppColors.cardBlue, AppColors.cardBlueBorder);
      case StatCardVariant.green:
        return (AppColors.cardGreen, AppColors.cardGreenBorder);
      case StatCardVariant.gray:
        return (AppColors.cardGray, AppColors.divider);
      case StatCardVariant.warning:
        return (AppColors.warningLight, AppColors.warning.withOpacity(0.35));
      case StatCardVariant.error:
        return (AppColors.errorLight, AppColors.error.withOpacity(0.35));
    }
  }
}