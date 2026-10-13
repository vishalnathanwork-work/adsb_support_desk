import 'package:flutter/material.dart';
import '../config/theme.dart';

/// One filter option in the row.
class FilterOption {
  final String label;
  final String value;
  final int? count;

  const FilterOption({
    required this.label,
    required this.value,
    this.count,
  });
}

/// Horizontal scrolling row of filter chips.
/// Unselected = light gray with border.
/// Selected = solid primary blue with white text.
class FilterChipRow extends StatelessWidget {
  final List<FilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final EdgeInsets padding;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.asMap().entries.map((entry) {
            final i = entry.key;
            final opt = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                right: i == options.length - 1 ? 0 : 8,
              ),
              child: _Chip(
                label: opt.label,
                count: opt.count,
                selected: opt.value == selectedValue,
                onTap: () => onSelected(opt.value),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final display = count == null ? label : '$label ($count)';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 1,
          ),
        ),
        child: Text(
          display,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}