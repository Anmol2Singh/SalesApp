// lib/core/widgets/date_grouped_list_view.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum DateGroupCategory {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  earlier;

  String get label {
    switch (this) {
      case DateGroupCategory.today:
        return 'Today';
      case DateGroupCategory.yesterday:
        return 'Yesterday';
      case DateGroupCategory.thisWeek:
        return 'This Week';
      case DateGroupCategory.thisMonth:
        return 'This Month';
      case DateGroupCategory.earlier:
        return 'Earlier';
    }
  }

  IconData get icon {
    switch (this) {
      case DateGroupCategory.today:
        return Icons.today_rounded;
      case DateGroupCategory.yesterday:
        return Icons.event_available_rounded;
      case DateGroupCategory.thisWeek:
        return Icons.date_range_rounded;
      case DateGroupCategory.thisMonth:
        return Icons.calendar_month_rounded;
      case DateGroupCategory.earlier:
        return Icons.history_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DateGroupCategory.today:
        return AppColors.primary;
      case DateGroupCategory.yesterday:
        return const Color(0xFF2563EB);
      case DateGroupCategory.thisWeek:
        return const Color(0xFF7C3AED);
      case DateGroupCategory.thisMonth:
        return const Color(0xFF0D9488);
      case DateGroupCategory.earlier:
        return AppColors.textSecondary;
    }
  }
}

/// Helper to categorize any DateTime into Today, Yesterday, This Week, This Month, Earlier
DateGroupCategory categorizeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final itemDay = DateTime(date.year, date.month, date.day);

  final diffDays = today.difference(itemDay).inDays;
  if (diffDays == 0) return DateGroupCategory.today;
  if (diffDays == 1) return DateGroupCategory.yesterday;

  // This week: Monday to Sunday of current week
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  if (itemDay.isAfter(startOfWeek.subtract(const Duration(seconds: 1)))) {
    return DateGroupCategory.thisWeek;
  }

  // This month: 1st day of current month
  final startOfMonth = DateTime(now.year, now.month, 1);
  if (itemDay.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))) {
    return DateGroupCategory.thisMonth;
  }

  return DateGroupCategory.earlier;
}

/// A reusable toggle button widget for toggling Date Grouping
class DateGroupingToggleButton extends StatelessWidget {
  final bool isGrouped;
  final ValueChanged<bool> onChanged;

  const DateGroupingToggleButton({
    super.key,
    required this.isGrouped,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isGrouped ? 'Switch to Flat List' : 'Group by Date',
      child: InkWell(
        onTap: () => onChanged(!isGrouped),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isGrouped
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isGrouped ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGrouped
                    ? Icons.calendar_view_day_rounded
                    : Icons.format_list_bulleted_rounded,
                size: 14,
                color: isGrouped ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Grouped',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: isGrouped ? FontWeight.bold : FontWeight.w500,
                  color: isGrouped ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable Date Grouped List View with sticky/section date headers.
class DateGroupedListView<T> extends StatelessWidget {
  final List<T> items;
  final DateTime Function(T item) dateSelector;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final bool isGrouped;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final Widget? emptyWidget;

  const DateGroupedListView({
    super.key,
    required this.items,
    required this.dateSelector,
    required this.itemBuilder,
    this.isGrouped = true,
    this.controller,
    this.padding = const EdgeInsets.all(12),
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return emptyWidget ??
          const Center(
            child: Text(
              'No items found.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
    }

    if (!isGrouped) {
      // Flat list view
      return ListView.separated(
        controller: controller,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => itemBuilder(ctx, items[i]),
      );
    }

    // Group items by category
    final Map<DateGroupCategory, List<T>> groups = {};
    for (final cat in DateGroupCategory.values) {
      groups[cat] = [];
    }

    for (final item in items) {
      final date = dateSelector(item);
      final cat = categorizeDate(date);
      groups[cat]!.add(item);
    }

    // Filter out empty groups
    final activeCategories = DateGroupCategory.values
        .where((cat) => groups[cat]!.isNotEmpty)
        .toList();

    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: activeCategories.length,
      itemBuilder: (ctx, catIndex) {
        final cat = activeCategories[catIndex];
        final catItems = groups[cat]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Container(
              margin: EdgeInsets.only(top: catIndex == 0 ? 0 : 12, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cat.color.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 14, color: cat.color),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cat.color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${catItems.length}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: cat.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Items in this section
            ...catItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: itemBuilder(ctx, item),
                )),
          ],
        );
      },
    );
  }
}

