import 'package:flutter/material.dart';
import '../config/theme.dart';

enum ActionTileVariant { blue, green, gray, warning, error }

/// A left-accented card used for dashboard quick actions.
/// Replaces the copy-pasted `_actionTile` helpers across dashboards.
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accentColor;
  final ActionTileVariant variant;

  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accentColor,
    this.variant = ActionTileVariant.blue,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border) = _surface();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: border, width: 1),
            ),
            child: Row(
              children: [
                // ⭐ Left accent bar
                Container(
                  width: 5,
                  height: 76,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.lg),
                      bottomLeft: Radius.circular(AppRadii.lg),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(
                    Icons.chevron_right,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color bg, Color border) _surface() {
    switch (variant) {
      case ActionTileVariant.blue:
        return (AppColors.cardBlue, AppColors.cardBlueBorder);
      case ActionTileVariant.green:
        return (AppColors.cardGreen, AppColors.cardGreenBorder);
      case ActionTileVariant.gray:
        return (AppColors.cardGray, AppColors.divider);
      case ActionTileVariant.warning:
        return (AppColors.warningLight, AppColors.warning.withOpacity(0.3));
      case ActionTileVariant.error:
        return (AppColors.errorLight, AppColors.error.withOpacity(0.3));
    }
  }
}