// lib/features/assigned_work/presentation/widgets/add_edit_work_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/assigned_work_item.dart';
import '../../providers/assigned_work_providers.dart';

class AddEditWorkDialog extends ConsumerStatefulWidget {
  final AssignedWorkItem? initialItem;
  final DateTime? initialDate;

  const AddEditWorkDialog({
    super.key,
    this.initialItem,
    this.initialDate,
  });

  static Future<bool?> show(BuildContext context, {AssignedWorkItem? item, DateTime? date}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditWorkDialog(
        initialItem: item,
        initialDate: date,
      ),
    );
  }

  @override
  ConsumerState<AddEditWorkDialog> createState() => _AddEditWorkDialogState();
}

class _AddEditWorkDialogState extends ConsumerState<AddEditWorkDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _customerSearchController;
  late TextEditingController _userSearchController;

  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  WorkPriority _priority = WorkPriority.medium;

  Profile? _assignedToUser;
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  bool _isLoading = false;
  String _userFilterQuery = '';

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descController = TextEditingController(text: item?.description ?? '');
    _customerSearchController = TextEditingController(text: item?.customerName ?? '');
    _userSearchController = TextEditingController();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialCandidate = item?.taskDate ?? widget.initialDate ?? today;
    _selectedDate = (item == null && initialCandidate.isBefore(today)) ? today : initialCandidate;
    _priority = item?.priority ?? WorkPriority.medium;

    if (item?.dueTime != null && item!.dueTime!.isNotEmpty) {
      try {
        final t = item.dueTime!.trim();
        if (t.toUpperCase().contains('AM') || t.toUpperCase().contains('PM')) {
          final isPm = t.toUpperCase().contains('PM');
          final clean = t.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
          final p = clean.split(':');
          var h = int.parse(p[0]);
          final m = int.parse(p[1]);
          if (isPm && h < 12) h += 12;
          if (!isPm && h == 12) h = 0;
          _selectedTime = TimeOfDay(hour: h, minute: m);
        } else {
          final parts = t.split(':');
          _selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}
    }

    _selectedCustomerId = item?.customerId;
    _selectedCustomerName = item?.customerName;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _customerSearchController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = widget.initialItem != null
        ? (widget.initialItem!.taskDate.isBefore(today) ? widget.initialItem!.taskDate : today)
        : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(minDate) ? minDate : _selectedDate,
      firstDate: minDate, // Past dates disallowed
      lastDate: today.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;
    final targetUser = _assignedToUser ?? currentProfile;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (widget.initialItem == null && selectedDay.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add or schedule work on past dates. Please select today or a future date.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedTime = _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null;

      final actions = ref.read(assignedWorkActionsProvider);

      if (widget.initialItem == null) {
        // Create
        final newItem = AssignedWorkItem(
          id: '',
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          taskDate: _selectedDate,
          dueTime: formattedTime,
          assignedToUserId: targetUser.id,
          assignedToUserName: targetUser.fullName.isNotEmpty ? targetUser.fullName : (targetUser.email.isNotEmpty ? targetUser.email : 'User'),
          assignedToUserRole: targetUser.primaryRole.displayName,
          assignedByUserId: currentProfile.id,
          assignedByUserName: currentProfile.fullName.isNotEmpty ? currentProfile.fullName : (currentProfile.email.isNotEmpty ? currentProfile.email : 'User'),
          assignedByUserRole: currentProfile.primaryRole.displayName,
          customerId: _selectedCustomerId,
          customerName: _selectedCustomerName ?? (_customerSearchController.text.trim().isNotEmpty ? _customerSearchController.text.trim() : null),
          priority: _priority,
          status: WorkStatus.pending,
          createdAt: DateTime.now(),
        );

        await actions.addWork(newItem);
      } else {
        // Update
        final updated = widget.initialItem!.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          taskDate: _selectedDate,
          dueTime: formattedTime,
          assignedToUserId: targetUser.id,
          assignedToUserName: targetUser.fullName.isNotEmpty ? targetUser.fullName : (targetUser.email.isNotEmpty ? targetUser.email : 'User'),
          assignedToUserRole: targetUser.primaryRole.displayName,
          customerId: _selectedCustomerId,
          customerName: _selectedCustomerName ?? (_customerSearchController.text.trim().isNotEmpty ? _customerSearchController.text.trim() : null),
          priority: _priority,
        );

        await actions.updateWork(updated);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialItem == null ? 'Task assigned successfully!' : 'Task updated successfully!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = ref.watch(currentProfileProvider);
    final isEdit = widget.initialItem != null;

    final assignableUsersAsync = ref.watch(assignableUsersProvider);
    final currentRoles = currentProfile?.roles ?? [];
    final canAssignOthers = currentRoles.contains(UserRole.admin) ||
        currentRoles.contains(UserRole.manager) ||
        currentRoles.contains(UserRole.salesHead);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_calendar_rounded : Icons.add_task_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Task' : 'Assign New Work',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          canAssignOthers
                              ? 'Assign task to team members with date & priority'
                              : 'Create or schedule a task for yourself',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Task Title *',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Client Follow-up, Site Survey, Quote review',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF6366F1), size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a task title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Assign to User (Searchable)
                      Row(
                        children: [
                          const Text(
                            'Assign To *',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (currentRoles.contains(UserRole.salesHead))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Sales Team Only',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      assignableUsersAsync.when(
                        data: (users) {
                          if (users.isEmpty) {
                            return Text(
                              'No assignable users found',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            );
                          }

                          // If _assignedToUser is null, find matches or default
                          if (_assignedToUser == null) {
                            if (widget.initialItem != null) {
                              _assignedToUser = users.firstWhere(
                                (u) => u.id == widget.initialItem!.assignedToUserId,
                                orElse: () => users.first,
                              );
                            } else {
                              _assignedToUser = users.firstWhere(
                                (u) => u.id == currentProfile?.id,
                                orElse: () => users.first,
                              );
                            }
                          }

                          return InkWell(
                            onTap: canAssignOthers ? () => _showUserPickerModal(users) : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF4F46E5),
                                    child: Text(
                                      (_assignedToUser?.fullName.isNotEmpty == true
                                              ? _assignedToUser!.fullName[0]
                                              : 'U')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _assignedToUser?.fullName ?? 'Select User',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          '${_assignedToUser?.primaryRole.displayName ?? ''} • ${_assignedToUser?.email ?? ''}',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canAssignOthers)
                                    const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B))
                                  else
                                    const Tooltip(
                                      message: 'Assigned to self',
                                      child: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Error loading users: $err', style: const TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 18),

                      // Date & Due Time
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Task Date *',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF4F46E5)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd MMM yyyy').format(_selectedDate),
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Due Time (Optional)',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _pickTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF64748B)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedTime != null
                                                ? _formatTimeOfDay(_selectedTime!)
                                                : 'Set time',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                              color: _selectedTime != null
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                        if (_selectedTime != null)
                                          GestureDetector(
                                            onTap: () => setState(() => _selectedTime = null),
                                            child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Priority Selection
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: WorkPriority.values.map((p) {
                          final isSelected = _priority == p;
                          Color badgeColor;
                          switch (p) {
                            case WorkPriority.low:
                              badgeColor = const Color(0xFF10B981);
                              break;
                            case WorkPriority.medium:
                              badgeColor = const Color(0xFF3B82F6);
                              break;
                            case WorkPriority.high:
                              badgeColor = const Color(0xFFF59E0B);
                              break;
                            case WorkPriority.urgent:
                              badgeColor = const Color(0xFFEF4444);
                              break;
                          }

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => setState(() => _priority = p),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? badgeColor.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? badgeColor : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      p.displayName,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? badgeColor : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Customer Name (Searchable, Optional)
                      Row(
                        children: [
                          const Text(
                            'Customer Name',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(Optional)',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final customersAsync = ref.watch(assignableCustomersProvider);
                          final hasCustomer = _selectedCustomerName != null && _selectedCustomerName!.trim().isNotEmpty;

                          return InkWell(
                            onTap: () {
                              final list = customersAsync.valueOrNull ?? [];
                              _showCustomerPickerModal(list);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasCustomer ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0),
                                  width: hasCustomer ? 1.4 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    hasCustomer ? Icons.business_rounded : Icons.person_search_rounded,
                                    color: hasCustomer ? const Color(0xFF4F46E5) : const Color(0xFF6366F1),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      hasCustomer
                                          ? _selectedCustomerName!
                                          : 'Click to search customers...',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13.5,
                                        fontWeight: hasCustomer ? FontWeight.w600 : FontWeight.w400,
                                        color: hasCustomer ? const Color(0xFF1E293B) : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  if (hasCustomer)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCustomerId = null;
                                          _selectedCustomerName = null;
                                          _customerSearchController.clear();
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Description / Remarks
                      const Text(
                        'Description / Notes',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add instructions, meeting agenda, or follow-up details...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSave,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(isEdit ? Icons.save_rounded : Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isLoading ? 'Saving...' : (isEdit ? 'Update Task' : 'Assign Task'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserPickerModal(List<Profile> users) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = users.where((u) {
              if (_userFilterQuery.isEmpty) return true;
              final q = _userFilterQuery.toLowerCase();
              return u.fullName.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q) ||
                  u.primaryRole.displayName.toLowerCase().contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Select Assignee',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _userSearchController,
                      autofocus: true,
                      onChanged: (val) {
                        setModalState(() => _userFilterQuery = val);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by user name or role...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No matching users found',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final u = filtered[i];
                                final isSel = _assignedToUser?.id == u.id;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                    foregroundColor: isSel ? Colors.white : const Color(0xFF334155),
                                    child: Text(
                                      (u.fullName.isNotEmpty ? u.fullName[0] : 'U').toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    u.fullName,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${u.primaryRole.displayName} • ${u.email}',
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                  ),
                                  trailing: isSel
                                      ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5))
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _assignedToUser = u;
                                    });
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomerPickerModal(List<Map<String, dynamic>> allCustomers) {
    final currentProfile = ref.read(currentProfileProvider);
    final roles = currentProfile?.roles ?? [];
    final canSeeAll = roles.contains(UserRole.admin) || roles.contains(UserRole.salesHead);
    String modalFilterQuery = '';
    final TextEditingController searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allCustomers.where((c) {
              if (modalFilterQuery.isEmpty) return true;
              final q = modalFilterQuery.toLowerCase();
              final name = (c['customer_name'] ?? '').toString().toLowerCase();
              final phone = (c['phone'] ?? '').toString().toLowerCase();
              final company = (c['company_name'] ?? '').toString().toLowerCase();
              final address = (c['address'] ?? '').toString().toLowerCase();
              return name.contains(q) || phone.contains(q) || company.contains(q) || address.contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Customer',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              canSeeAll
                                  ? 'All Customers (${allCustomers.length})'
                                  : 'Your Assigned Customers (${allCustomers.length})',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (val) {
                        setModalState(() => modalFilterQuery = val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by customer name, phone, company...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setModalState(() => modalFilterQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (modalFilterQuery.isNotEmpty)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = null;
                            _selectedCustomerName = modalFilterQuery;
                            _customerSearchController.text = modalFilterQuery;
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Use "$modalFilterQuery" as custom name',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                modalFilterQuery.isEmpty
                                    ? 'No customers found for your role'
                                    : 'No customer matching "$modalFilterQuery"',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = filtered[i];
                                final id = c['id']?.toString();
                                final name = c['customer_name']?.toString() ?? 'Customer';
                                final phone = c['phone']?.toString() ?? '';
                                final company = c['company_name']?.toString() ?? '';
                                final isSel = _selectedCustomerId == id || _selectedCustomerName == name;

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: isSel ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
                                    foregroundColor: isSel ? Colors.white : const Color(0xFF4338CA),
                                    child: const Icon(Icons.business_rounded, size: 16),
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                      color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  subtitle: Text(
                                    [if (company.isNotEmpty) company, if (phone.isNotEmpty) phone].join(' • '),
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                  ),
                                  trailing: isSel
                                      ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5))
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedCustomerId = id;
                                      _selectedCustomerName = name;
                                      _customerSearchController.text = name;
                                    });
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
