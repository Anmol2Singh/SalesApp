import 'package:intl/intl.dart';

enum CrmDatePreset {
  all,
  today,
  yesterday,
  last7Days,
  thisMonth,
  lastMonth,
  custom;

  String get displayName {
    switch (this) {
      case CrmDatePreset.all:
        return 'All Time';
      case CrmDatePreset.today:
        return 'Today';
      case CrmDatePreset.yesterday:
        return 'Yesterday';
      case CrmDatePreset.last7Days:
        return 'Last 7 Days';
      case CrmDatePreset.thisMonth:
        return 'This Month';
      case CrmDatePreset.lastMonth:
        return 'Last Month';
      case CrmDatePreset.custom:
        return 'Custom Range';
    }
  }
}

class CrmDateFilter {
  final CrmDatePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool isGrouped;

  const CrmDateFilter({
    this.preset = CrmDatePreset.all,
    this.customStart,
    this.customEnd,
    this.isGrouped = false,
  });

  bool get isActive => preset != CrmDatePreset.all;

  DateTime? get startDate {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case CrmDatePreset.all:
        return null;
      case CrmDatePreset.today:
        return todayStart;
      case CrmDatePreset.yesterday:
        return todayStart.subtract(const Duration(days: 1));
      case CrmDatePreset.last7Days:
        return todayStart.subtract(const Duration(days: 7));
      case CrmDatePreset.thisMonth:
        return DateTime(now.year, now.month, 1);
      case CrmDatePreset.lastMonth:
        return DateTime(now.year, now.month - 1, 1);
      case CrmDatePreset.custom:
        return customStart != null
            ? DateTime(customStart!.year, customStart!.month, customStart!.day)
            : null;
    }
  }

  DateTime? get endDate {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (preset) {
      case CrmDatePreset.all:
        return null;
      case CrmDatePreset.today:
        return todayEnd;
      case CrmDatePreset.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
      case CrmDatePreset.last7Days:
        return todayEnd;
      case CrmDatePreset.thisMonth:
        return todayEnd;
      case CrmDatePreset.lastMonth:
        final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
        return DateTime(lastDayOfPrevMonth.year, lastDayOfPrevMonth.month,
            lastDayOfPrevMonth.day, 23, 59, 59, 999);
      case CrmDatePreset.custom:
        return customEnd != null
            ? DateTime(customEnd!.year, customEnd!.month, customEnd!.day, 23,
                59, 59, 999)
            : null;
    }
  }

  String get label {
    final formatter = DateFormat('dd MMM');
    if (preset == CrmDatePreset.custom &&
        customStart != null &&
        customEnd != null) {
      return '${formatter.format(customStart!)} - ${formatter.format(customEnd!)}';
    }
    return preset.displayName;
  }

  /// Groups a given DateTime into standard CRM buckets:
  /// Today, Yesterday, {dates}... (e.g. 24 Oct 2026, 23 Oct 2026)
  static String getBucket(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    if (localDate.isAfter(todayStart) || localDate.isAtSameMomentAs(todayStart)) {
      return 'Today';
    } else if (localDate.isAfter(yesterdayStart) ||
        localDate.isAtSameMomentAs(yesterdayStart)) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMM yyyy').format(localDate);
    }
  }

  CrmDateFilter copyWith({
    CrmDatePreset? preset,
    DateTime? customStart,
    DateTime? customEnd,
    bool? isGrouped,
  }) {
    return CrmDateFilter(
      preset: preset ?? this.preset,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      isGrouped: isGrouped ?? this.isGrouped,
    );
  }
}
