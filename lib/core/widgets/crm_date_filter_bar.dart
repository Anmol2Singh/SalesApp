import 'package:flutter/material.dart';
import '../models/crm_date_filter.dart';
import '../theme/app_theme.dart';

class CrmDateFilterBar extends StatelessWidget {
  final CrmDateFilter filter;
  final ValueChanged<CrmDateFilter> onFilterChanged;
  final int resultCount;
  final String dateFieldName; // e.g. "created_at" or "won date"

  const CrmDateFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.resultCount,
    this.dateFieldName = 'date',
  });

  Future<void> _selectCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: filter.customStart != null && filter.customEnd != null
          ? DateTimeRange(start: filter.customStart!, end: filter.customEnd!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onFilterChanged(
        filter.copyWith(
          preset: CrmDatePreset.custom,
          customStart: picked.start,
          customEnd: picked.end,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Presets Dropdown
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: filter.isActive ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: filter.isActive ? AppColors.primary : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CrmDatePreset>(
                    value: filter.preset,
                    icon: Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: filter.isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                    isDense: true,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: filter.isActive ? FontWeight.bold : FontWeight.w500,
                      color: filter.isActive ? AppColors.primary : AppColors.textPrimary,
                    ),
                    items: CrmDatePreset.values.map((preset) {
                      return DropdownMenuItem<CrmDatePreset>(
                        value: preset,
                        child: Text(preset.displayName),
                      );
                    }).toList(),
                    onChanged: (newPreset) {
                      if (newPreset == null) return;
                      if (newPreset == CrmDatePreset.custom) {
                        _selectCustomRange(context);
                      } else {
                        onFilterChanged(
                          filter.copyWith(
                            preset: newPreset,
                            customStart: null,
                            customEnd: null,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Grouping Toggle Button
              InkWell(
                onTap: () {
                  onFilterChanged(filter.copyWith(isGrouped: !filter.isGrouped));
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: filter.isGrouped ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: filter.isGrouped ? const Color(0xFF10B981) : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter.isGrouped ? Icons.view_agenda : Icons.view_agenda_outlined,
                        size: 16,
                        color: filter.isGrouped ? const Color(0xFF10B981) : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMobile ? (filter.isGrouped ? 'Grouped' : 'Group') : (filter.isGrouped ? 'Grouped by Date' : 'Group by Date'),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: filter.isGrouped ? FontWeight.bold : FontWeight.normal,
                          color: filter.isGrouped ? const Color(0xFF047857) : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Result Count Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                ),
                child: Text(
                  '$resultCount items',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Active filter chip row (when filter is active)
          if (filter.isActive) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                InputChip(
                  label: Text('${filter.label} ($dateFieldName)'),
                  labelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  avatar: const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                  onDeleted: () {
                    onFilterChanged(
                      filter.copyWith(
                        preset: CrmDatePreset.all,
                        customStart: null,
                        customEnd: null,
                      ),
                    );
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    onFilterChanged(
                      filter.copyWith(
                        preset: CrmDatePreset.all,
                        customStart: null,
                        customEnd: null,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

