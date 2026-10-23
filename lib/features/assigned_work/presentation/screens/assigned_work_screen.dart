// lib/features/assigned_work/presentation/screens/assigned_work_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/assigned_work_item.dart';
import '../../providers/assigned_work_providers.dart';
import '../widgets/add_edit_work_dialog.dart';

class AssignedWorkScreen extends ConsumerStatefulWidget {
  const AssignedWorkScreen({super.key});

  @override
  ConsumerState<AssignedWorkScreen> createState() => _AssignedWorkScreenState();
}

class _AssignedWorkScreenState extends ConsumerState<AssignedWorkScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _monthSlideForward = true;
  bool _daySlideForward = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() => _monthSlideForward = false);
    final current = ref.read(assignedWorkMonthProvider);
    final prev = DateTime(current.year, current.month - 1, 1);
    ref.read(assignedWorkMonthProvider.notifier).state = prev;
  }

  void _nextMonth() {
    setState(() => _monthSlideForward = true);
    final current = ref.read(assignedWorkMonthProvider);
    final next = DateTime(current.year, current.month + 1, 1);
    ref.read(assignedWorkMonthProvider.notifier).state = next;
  }

  void _previousDay() {
    final current = ref.read(assignedWorkSelectedDateProvider);
    final prev = current.subtract(const Duration(days: 1));
    setState(() => _daySlideForward = false);
    ref.read(assignedWorkSelectedDateProvider.notifier).state = prev;

    final month = ref.read(assignedWorkMonthProvider);
    if (prev.month != month.month || prev.year != month.year) {
      setState(() => _monthSlideForward = false);
      ref.read(assignedWorkMonthProvider.notifier).state = DateTime(prev.year, prev.month, 1);
    }
  }

  void _nextDay() {
    final current = ref.read(assignedWorkSelectedDateProvider);
    final next = current.add(const Duration(days: 1));
    setState(() => _daySlideForward = true);
    ref.read(assignedWorkSelectedDateProvider.notifier).state = next;

    final month = ref.read(assignedWorkMonthProvider);
    if (next.month != month.month || next.year != month.year) {
      setState(() => _monthSlideForward = true);
      ref.read(assignedWorkMonthProvider.notifier).state = DateTime(next.year, next.month, 1);
    }
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentSel = ref.read(assignedWorkSelectedDateProvider);
    setState(() {
      _daySlideForward = today.isAfter(currentSel);
      _monthSlideForward = today.isAfter(ref.read(assignedWorkMonthProvider));
    });
    ref.read(assignedWorkMonthProvider.notifier).state = DateTime(now.year, now.month, 1);
    ref.read(assignedWorkSelectedDateProvider.notifier).state = today;
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = ref.watch(assignedWorkMonthProvider);
    final selectedDate = ref.watch(assignedWorkSelectedDateProvider);
    final monthTasksAsync = ref.watch(assignedWorkMonthItemsProvider);
    final selectedTasksAsync = ref.watch(selectedDateTasksProvider);
    final statusFilter = ref.watch(assignedWorkStatusFilterProvider);
    final userFilter = ref.watch(assignedWorkUserFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.dashboard);
            }
          },
        ),
        title: const Text(
          'Assigned Work',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _goToToday,
            icon: const Icon(Icons.today_rounded, color: Colors.white, size: 20),
            tooltip: 'Go to Today',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => AddEditWorkDialog.show(context, date: selectedDate),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Add Work',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 1,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          heroTag: 'assigned_work_fab_add',
          onPressed: () => AddEditWorkDialog.show(context, date: selectedDate),
          backgroundColor: const Color(0xFF10B981),
          elevation: 4,
          shape: const CircleBorder(),
          tooltip: 'Add Task / Work',
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Calendar + Month Overview
                SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCalendarCard(context, currentMonth, selectedDate, monthTasksAsync),
                        const SizedBox(height: 16),
                        _buildMonthSummaryCard(monthTasksAsync, currentMonth),
                      ],
                    ),
                  ),
                ),

                const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

                // Right side: Filter & Tasks for Selected Date
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterBar(statusFilter, userFilter),
                        const SizedBox(height: 16),
                        _buildDateHeader(selectedDate),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _buildTaskList(selectedTasksAsync, selectedDate),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile / Tablet layout
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCalendarCard(context, currentMonth, selectedDate, monthTasksAsync),
                const SizedBox(height: 10),
                _buildFilterBar(statusFilter, userFilter),
                const SizedBox(height: 10),
                _buildDateHeader(selectedDate),
                const SizedBox(height: 8),
                _buildTaskList(selectedTasksAsync, selectedDate, shrinkWrap: true),
                const SizedBox(height: 90),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── CALENDAR WIDGET ─────────────────────────────────────────────────────────

  Widget _buildCalendarCard(
    BuildContext context,
    DateTime currentMonth,
    DateTime selectedDate,
    AsyncValue<List<AssignedWorkItem>> monthTasksAsync,
  ) {
    final items = monthTasksAsync.valueOrNull ?? [];

    final monthTitle = DateFormat('MMMM yyyy').format(currentMonth);

    // Days in current month
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    // Days to show: start on Monday
    // DateTime.weekday: 1 = Mon, 7 = Sun
    final leadingEmpty = firstDayOfMonth.weekday - 1; // 0 for Mon, 6 for Sun
    final totalDays = lastDayOfMonth.day;
    final totalSlots = leadingEmpty + totalDays;
    final numWeeks = (totalSlots / 7).ceil();

    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    double dragDistance = 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => dragDistance = 0,
      onHorizontalDragUpdate: (details) => dragDistance += details.primaryDelta ?? 0,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120 || dragDistance < -40) {
          _nextMonth();
        } else if (velocity > 120 || dragDistance > 40) {
          _previousMonth();
        }
      },
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month navigation header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  monthTitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Color(0xFF475569)),
                  onPressed: _previousMonth,
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Color(0xFF475569)),
                  onPressed: _nextMonth,
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Calendar Grid - Weekly rows with smooth swipe animation
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offset = _monthSlideForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: offset,
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Column(
                  key: ValueKey<String>('${currentMonth.year}-${currentMonth.month}'),
                  children: [
                    for (int week = 0; week < numWeeks; week++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            for (int col = 0; col < 7; col++) ...[
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final slotIndex = week * 7 + col;
                                    if (slotIndex < leadingEmpty || slotIndex >= totalSlots) {
                                      return const SizedBox.shrink();
                                    }

                                    final dayNumber = slotIndex - leadingEmpty + 1;
                                    final cellDate = DateTime(currentMonth.year, currentMonth.month, dayNumber);
                                    final dayTasks = mapTasksForDate(items, cellDate);

                                    final isSelected = cellDate.year == selectedDate.year &&
                                        cellDate.month == selectedDate.month &&
                                        cellDate.day == selectedDate.day;

                                    final isToday = cellDate.year == todayNormalized.year &&
                                        cellDate.month == todayNormalized.month &&
                                        cellDate.day == todayNormalized.day;

                                    final pendingCount = dayTasks.where((t) => !t.isTrace && t.status == WorkStatus.pending).length;
                                    final completedCount = dayTasks.where((t) => !t.isTrace && t.status == WorkStatus.completed).length;
                                    final traceCount = dayTasks.where((t) => t.isTrace).length;

                                    return AspectRatio(
                                      aspectRatio: 1.0,
                                      child: InkWell(
                                        onTap: () {
                                          final current = ref.read(assignedWorkSelectedDateProvider);
                                          if (cellDate.isAfter(current)) {
                                            setState(() => _daySlideForward = true);
                                          } else if (cellDate.isBefore(current)) {
                                            setState(() => _daySlideForward = false);
                                          }
                                          ref.read(assignedWorkSelectedDateProvider.notifier).state = cellDate;
                                        },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : (isToday ? const Color(0xFFEEF2FF) : Colors.transparent),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF4338CA)
                                              : (isToday ? const Color(0xFF818CF8) : Colors.transparent),
                                          width: isSelected || isToday ? 1.5 : 0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$dayNumber',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 13,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isToday ? const Color(0xFF312E81) : const Color(0xFF1E293B)),
                                            ),
                                          ),
                                          if (dayTasks.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (traceCount > 0)
                                                  Container(
                                                    width: 5.5,
                                                    height: 5.5,
                                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? Colors.white60 : const Color(0xFF94A3B8),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                if (pendingCount > 0)
                                                  Container(
                                                    width: 5.5,
                                                    height: 5.5,
                                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? Colors.amberAccent : const Color(0xFFF59E0B),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                if (completedCount > 0)
                                                  Container(
                                                    width: 5.5,
                                                    height: 5.5,
                                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? Colors.white70 : const Color(0xFF10B981),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (col < 6) const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),

          // Legend Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDotLegend(const Color(0xFFF59E0B), 'Pending'),
                const SizedBox(width: 14),
                _buildDotLegend(const Color(0xFF10B981), 'Completed'),
                const SizedBox(width: 14),
                _buildDotLegend(const Color(0xFF94A3B8), 'Moved Trace (Gray)'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildDotLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ─── MONTH SUMMARY CARD ─────────────────────────────────────────────────────

  Widget _buildMonthSummaryCard(
    AsyncValue<List<AssignedWorkItem>> monthTasksAsync,
    DateTime currentMonth,
  ) {
    final items = monthTasksAsync.valueOrNull ?? [];
    final monthItems = items.where((it) {
      return it.taskDate.year == currentMonth.year && it.taskDate.month == currentMonth.month;
    }).toList();

    final total = monthItems.length;
    final completed = monthItems.where((t) => t.status == WorkStatus.completed).length;
    final pending = monthItems.where((t) => t.status == WorkStatus.pending).length;
    final percent = total > 0 ? (completed / total * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF4F46E5), size: 18),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('MMMM').format(currentMonth)} Progress',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? (completed / total) : 0,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF10B981),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMiniStat('Total Tasks', '$total', const Color(0xFF64748B)),
              _buildMiniStat('Pending', '$pending', const Color(0xFFF59E0B)),
              _buildMiniStat('Done', '$completed', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTER BAR ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar(String activeStatus, String activeUserScope) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Status Chips
          _buildFilterChip('All Status', 'all', activeStatus, (val) {
            ref.read(assignedWorkStatusFilterProvider.notifier).state = val;
          }),
          _buildFilterChip('Pending', 'pending', activeStatus, (val) {
            ref.read(assignedWorkStatusFilterProvider.notifier).state = val;
          }),
          _buildFilterChip('Completed', 'completed', activeStatus, (val) {
            ref.read(assignedWorkStatusFilterProvider.notifier).state = val;
          }),

          const SizedBox(width: 8),
          Container(height: 20, width: 1, color: const Color(0xFFE2E8F0)),
          const SizedBox(width: 8),

          // User Scope Chips
          _buildFilterChip('All Team', 'all', activeUserScope, (val) {
            ref.read(assignedWorkUserFilterProvider.notifier).state = val;
          }),
          _buildFilterChip('Assigned to Me', 'assigned_to_me', activeUserScope, (val) {
            ref.read(assignedWorkUserFilterProvider.notifier).state = val;
          }),
          _buildFilterChip('Assigned by Me', 'assigned_by_me', activeUserScope, (val) {
            ref.read(assignedWorkUserFilterProvider.notifier).state = val;
          }),

          const SizedBox(width: 12),

          // Search Field
          SizedBox(
            width: 200,
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(assignedWorkSearchQueryProvider.notifier).state = val;
              },
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(assignedWorkSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = value == currentValue;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ─── DATE HEADER ────────────────────────────────────────────────────────────

  Widget _buildDateHeader(DateTime selectedDate) {
    final formatted = DateFormat('EEE, dd MMM yyyy').format(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selNormalized = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isToday = selNormalized.isAtSameMomentAs(today);
    final isPast = selNormalized.isBefore(today);

    return Row(
      children: [
        Icon(
          Icons.calendar_month,
          size: 18,
          color: isToday
              ? const Color(0xFF4F46E5)
              : (isPast ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  formatted,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isPast ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4338CA),
                    ),
                  ),
                ),
              ] else if (isPast) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'PAST DATE (READ-ONLY)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20, color: Color(0xFF64748B)),
                onPressed: _previousDay,
                tooltip: 'Previous Day',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF64748B)),
                onPressed: _nextDay,
                tooltip: 'Next Day',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!isPast)
          TextButton.icon(
            onPressed: () => AddEditWorkDialog.show(context, date: selectedDate),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Task'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  // ─── TASK LIST ──────────────────────────────────────────────────────────────

  Widget _buildTaskList(
    AsyncValue<List<AssignedWorkItem>> tasksAsync,
    DateTime selectedDate, {
    bool shrinkWrap = false,
  }) {
    double dragAccumulator = 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => dragAccumulator = 0,
      onHorizontalDragUpdate: (details) => dragAccumulator += details.primaryDelta ?? 0,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120 || dragAccumulator < -40) {
          _nextDay();
        } else if (velocity > 120 || dragAccumulator > 40) {
          _previousDay();
        }
      },
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offset = _daySlideForward ? const Offset(0.35, 0.0) : const Offset(-0.35, 0.0);
            return SlideTransition(
              position: Tween<Offset>(
                begin: offset,
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<String>('${selectedDate.year}-${selectedDate.month}-${selectedDate.day}'),
            child: tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final selNormalized = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                  final isPast = selNormalized.isBefore(today);

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isPast ? const Color(0xFFF1F5F9) : const Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPast ? Icons.history_toggle_off_rounded : Icons.event_available_rounded,
                              size: 48,
                              color: isPast ? const Color(0xFF94A3B8) : const Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isPast ? 'No Tasks on This Past Date' : 'No Tasks for This Date',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isPast
                                ? 'No active tasks or traces on this day. Tasks cannot be added in the past.'
                                : 'Tap "Add Work" to assign tasks to team members or yourself.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          if (isPast)
                            ElevatedButton.icon(
                              onPressed: () {
                                ref.read(assignedWorkSelectedDateProvider.notifier).state = today;
                                AddEditWorkDialog.show(context, date: today);
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Work for Today'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => AddEditWorkDialog.show(context, date: selectedDate),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add New Work'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: shrinkWrap,
                  physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskCard(task);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading tasks: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── TASK CARD ──────────────────────────────────────────────────────────────

  Widget _buildTaskCard(AssignedWorkItem task) {
    if (task.isTrace) {
      return _buildTraceTaskCard(task);
    }
    return _buildActiveTaskCard(task);
  }

  /// Gray trace card for tasks left unfinished and moved forward
  Widget _buildTraceTaskCard(AssignedWorkItem task) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Trace Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Unfinished on this day • Moved to next day',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TRACE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trace indicator icon
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.redo_rounded, size: 15, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 12),

                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (task.dueTime != null && task.dueTime!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  task.dueTimeFormatted ?? task.dueTime!,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Muted Priority Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.priority.displayName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),

                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      task.description,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Assigned metadata (grayed)
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'To: ${task.assignedToUserName}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      if (task.customerName != null && task.customerName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            task.customerName!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Active task card with prominent "Mark as Complete" button and rollover notice
  Widget _buildActiveTaskCard(AssignedWorkItem task) {
    final isDone = task.status == WorkStatus.completed;

    // Block unmarking tasks completed on a previous day
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(task.taskDate.year, task.taskDate.month, task.taskDate.day);
    final isPastDayCompleted = isDone && taskDay.isBefore(today);

    Color priorityColor;
    switch (task.priority) {
      case WorkPriority.low:
        priorityColor = const Color(0xFF10B981);
        break;
      case WorkPriority.medium:
        priorityColor = const Color(0xFF3B82F6);
        break;
      case WorkPriority.high:
        priorityColor = const Color(0xFFF59E0B);
        break;
      case WorkPriority.urgent:
        priorityColor = const Color(0xFFEF4444);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rolled Over Notice Banner
            if (task.isRolledOver) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.update_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Auto-moved from ${DateFormat('EEE, dd MMM').format(task.taskDate)} (Unfinished on that day)',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Top Row: Status Checkbox + Title + Priority + Options Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Checkbox
                InkWell(
                  onTap: isPastDayCompleted
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Cannot undo tasks completed on a previous day.')),
                                ],
                              ),
                              backgroundColor: Color(0xFFB45309),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      : () {
                          ref.read(assignedWorkActionsProvider).toggleComplete(task.id, !isDone);
                        },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isPastDayCompleted
                          ? const Color(0xFFD1FAE5)
                          : (isDone ? const Color(0xFF10B981) : Colors.white),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPastDayCompleted
                            ? const Color(0xFF6EE7B7)
                            : (isDone ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                        width: 2,
                      ),
                    ),
                    child: isDone
                        ? Icon(isPastDayCompleted ? Icons.lock : Icons.check, size: 16,
                            color: isPastDayCompleted ? const Color(0xFF059669) : Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDone ? Colors.grey.shade400 : const Color(0xFF1E293B),
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.dueTime != null && task.dueTime!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              task.dueTimeFormatted ?? task.dueTime!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Priority Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.displayName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      AddEditWorkDialog.show(context, item: task);
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Task?'),
                          content: Text('Are you sure you want to delete "${task.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(assignedWorkActionsProvider).deleteWork(task.id);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Task')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),

            // Description
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  task.description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: isDone ? Colors.grey.shade400 : const Color(0xFF475569),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Chips Row: Assigned To, Assigned By, Customer
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Assigned To
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 14, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 4),
                        Text(
                          'To: ${task.assignedToUserName}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                        if (task.assignedToUserRole != null)
                          Text(
                            ' (${task.assignedToUserRole})',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              color: const Color(0xFF4338CA).withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Assigned By
                  if (task.assignedByUserName != task.assignedToUserName)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'By: ${task.assignedByUserName}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Customer Link
                  if (task.customerName != null && task.customerName!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_rounded, size: 13, color: Color(0xFFDB2777)),
                          const SizedBox(width: 4),
                          Text(
                            task.customerName!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFBE185D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Completed Chip (if done)
                  if (isDone && task.completedAt != null) ...[
                    Builder(
                      builder: (context) {
                        final completerName = (task.completedByUserName != null && task.completedByUserName!.trim().isNotEmpty)
                            ? task.completedByUserName!.trim()
                            : (task.assignedToUserName.trim().isNotEmpty ? task.assignedToUserName.trim() : task.assignedByUserName.trim());
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPastDayCompleted ? Icons.lock : Icons.check_circle,
                                size: 12,
                                color: const Color(0xFF059669),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Completed ${DateFormat('dd MMM, hh:mm a').format(task.completedAt!)}'
                                '${completerName.isNotEmpty ? ' by $completerName' : ''}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
