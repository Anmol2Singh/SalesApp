// lib/features/daily_tasks/widgets/task_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/customer.dart';
import '../models/daily_task_model.dart';
import '../providers/daily_tasks_provider.dart';
import '../../crm/data/models/prospect_model.dart';
import '../../crm/data/models/lead_model.dart';
import '../../crm/providers/crm_providers.dart';

enum DailyTaskTargetType {
  customer('Customer', Icons.business_outlined),
  prospect('Prospect', Icons.person_search_outlined),
  lead('Lead', Icons.trending_up_rounded),
  factoryOffice('Factory / Office', Icons.factory_outlined);

  final String label;
  final IconData icon;
  const DailyTaskTargetType(this.label, this.icon);
}

class TaskFormDialog extends ConsumerStatefulWidget {
  final DailyTask? taskToEdit;
  final String? preselectedCustomerId;
  final String? preselectedCustomerName;

  const TaskFormDialog({
    super.key,
    this.taskToEdit,
    this.preselectedCustomerId,
    this.preselectedCustomerName,
  });

  static Future<bool?> show(
    BuildContext context, {
    DailyTask? taskToEdit,
    String? preselectedCustomerId,
    String? preselectedCustomerName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TaskFormDialog(
        taskToEdit: taskToEdit,
        preselectedCustomerId: preselectedCustomerId,
        preselectedCustomerName: preselectedCustomerName,
      ),
    );
  }

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _taskController;
  late final TextEditingController _customerSearchController;

  DailyTaskTargetType _targetType = DailyTaskTargetType.customer;
  String _factoryOfficeLocation = 'Factory'; // 'Factory' or 'Office'

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(text: widget.taskToEdit?.taskDescription ?? '');
    _customerSearchController = TextEditingController();

    _selectedCustomerId = widget.taskToEdit?.customerId ?? widget.preselectedCustomerId;
    _selectedCustomerName = widget.taskToEdit?.customerName ?? widget.preselectedCustomerName;

    final initialName = _selectedCustomerName;
    if (initialName != null) {
      final lower = initialName.toLowerCase();
      if (lower.contains('factory')) {
        _targetType = DailyTaskTargetType.factoryOffice;
        _factoryOfficeLocation = 'Factory';
        _selectedCustomerName = 'Factory Work';
      } else if (lower.contains('office')) {
        _targetType = DailyTaskTargetType.factoryOffice;
        _factoryOfficeLocation = 'Office';
        _selectedCustomerName = 'Office Work';
      } else if (initialName.startsWith('[Prospect]')) {
        _targetType = DailyTaskTargetType.prospect;
      } else if (initialName.startsWith('[Lead]')) {
        _targetType = DailyTaskTargetType.lead;
      } else {
        _targetType = DailyTaskTargetType.customer;
      }
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_targetType == DailyTaskTargetType.factoryOffice) {
      if (_selectedCustomerName == null || _selectedCustomerName!.trim().isEmpty) {
        _selectedCustomerName = '$_factoryOfficeLocation Work';
      }
    } else {
      if (_selectedCustomerName == null || _selectedCustomerName!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a ${_targetType.label} (compulsory)'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.taskToEdit != null) {
        // Edit existing task
        await ref.read(dailyTasksProvider.notifier).updateTask(
          widget.taskToEdit!.id,
          taskDescription: _taskController.text.trim(),
          customerId: _selectedCustomerId,
          customerName: _selectedCustomerName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task updated successfully (logged as edited)'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new task
        await ref.read(dailyTasksProvider.notifier).createTask(
          customerId: _selectedCustomerId ?? '',
          customerName: _selectedCustomerName!,
          taskDescription: _taskController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task submitted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCustomerPicker(List<Customer> customers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerPickerSheet(
        customers: customers,
        initialSelectedId: _selectedCustomerId,
        onSelected: (customer) {
          setState(() {
            _selectedCustomerId = customer.id;
            _selectedCustomerName = customer.customerName.trim().isNotEmpty
                ? customer.customerName
                : (customer.contactPerson?.isNotEmpty == true ? customer.contactPerson! : customer.companyName);
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showProspectPicker(List<Prospect> prospects) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProspectPickerSheet(
        prospects: prospects,
        initialSelectedName: _selectedCustomerName,
        onSelected: (prospect) {
          setState(() {
            _selectedCustomerId = null;
            _selectedCustomerName = '[Prospect] ${prospect.name}';
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showLeadPicker(List<Lead> leads, List<Prospect> prospects) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LeadPickerSheet(
        leads: leads,
        prospects: prospects,
        initialSelectedName: _selectedCustomerName,
        onSelected: (lead, displayName) {
          setState(() {
            _selectedCustomerId = lead.convertedToCustomerId;
            _selectedCustomerName = '[Lead] $displayName (${lead.productName})';
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(taskSelectableCustomersProvider);
    final prospectsAsync = ref.watch(taskSelectableProspectsProvider);
    final leadsAsync = ref.watch(leadsProvider);
    final isEditing = widget.taskToEdit != null;
    final now = DateTime.now();

    final String targetLabel = _targetType == DailyTaskTargetType.factoryOffice
        ? 'Factory / Office Location'
        : '${_targetType.label} Name';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
                        color: const Color(0xFF1E1B4B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Completed Task' : 'Log Daily Task Completed',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? 'Changes will be saved and logged as edited.'
                                : (_targetType == DailyTaskTargetType.factoryOffice
                                    ? 'Record factory or office work report by staff.'
                                    : 'Record work done for ${_targetType.label.toLowerCase()} with automatic timestamp.'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Choice Category: Customer, Prospect, Lead, Factory/Office
                const Row(
                  children: [
                    Text(
                      'Log Work For',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DailyTaskTargetType.values.map((type) {
                    final isSelected = _targetType == type;
                    return ChoiceChip(
                      selected: isSelected,
                      onSelected: isEditing
                          ? null
                          : (selected) {
                              if (selected) {
                                setState(() {
                                  _targetType = type;
                                  if (type == DailyTaskTargetType.factoryOffice) {
                                    _selectedCustomerName = '$_factoryOfficeLocation Work';
                                    _selectedCustomerId = null;
                                  } else {
                                    _selectedCustomerName = null;
                                    _selectedCustomerId = null;
                                  }
                                });
                              }
                            },
                      avatar: Icon(
                        type.icon,
                        size: 15,
                        color: isSelected ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                      label: Text(type.label),
                      selectedColor: const Color(0xFF1E1B4B),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Selection Field according to chosen category
                Row(
                  children: [
                    Text(
                      targetLabel,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),

                if (_targetType == DailyTaskTargetType.factoryOffice) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _factoryOfficeLocation = 'Factory';
                              _selectedCustomerName = 'Factory Work';
                              _selectedCustomerId = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _factoryOfficeLocation == 'Factory'
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _factoryOfficeLocation == 'Factory'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFCBD5E1),
                                width: _factoryOfficeLocation == 'Factory' ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.factory_rounded,
                                  size: 18,
                                  color: _factoryOfficeLocation == 'Factory'
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Factory Work',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: _factoryOfficeLocation == 'Factory' ? FontWeight.bold : FontWeight.w600,
                                    color: _factoryOfficeLocation == 'Factory'
                                        ? const Color(0xFFB45309)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _factoryOfficeLocation = 'Office';
                              _selectedCustomerName = 'Office Work';
                              _selectedCustomerId = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _factoryOfficeLocation == 'Office'
                                  ? const Color(0xFFCCFBF1)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _factoryOfficeLocation == 'Office'
                                    ? const Color(0xFF14B8A6)
                                    : const Color(0xFFCBD5E1),
                                width: _factoryOfficeLocation == 'Office' ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.apartment_rounded,
                                  size: 18,
                                  color: _factoryOfficeLocation == 'Office'
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Office Work',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: _factoryOfficeLocation == 'Office' ? FontWeight.bold : FontWeight.w600,
                                    color: _factoryOfficeLocation == 'Office'
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_targetType == DailyTaskTargetType.customer) ...[
                  customersAsync.when(
                    data: (customers) {
                      final isPreselected = widget.preselectedCustomerId != null && widget.preselectedCustomerId!.isNotEmpty;

                      return InkWell(
                        onTap: isPreselected ? null : () => _showCustomerPicker(customers),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isPreselected ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCustomerName != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.business_outlined, size: 20, color: Color(0xFF64748B)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedCustomerName ?? 'Tap to select customer...',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: _selectedCustomerName != null ? FontWeight.w600 : FontWeight.w400,
                                    color: _selectedCustomerName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              if (!isPreselected)
                                const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading customers: $e', style: const TextStyle(color: AppColors.error)),
                  ),
                ] else if (_targetType == DailyTaskTargetType.prospect) ...[
                  prospectsAsync.when(
                    data: (prospects) {
                      return InkWell(
                        onTap: () => _showProspectPicker(prospects),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCustomerName != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_search_outlined, size: 20, color: Color(0xFF2563EB)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedCustomerName ?? 'Tap to select prospect...',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: _selectedCustomerName != null ? FontWeight.w600 : FontWeight.w400,
                                    color: _selectedCustomerName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading prospects: $e', style: const TextStyle(color: AppColors.error)),
                  ),
                ] else if (_targetType == DailyTaskTargetType.lead) ...[
                  leadsAsync.when(
                    data: (leads) {
                      final prospects = prospectsAsync.value ?? [];
                      return InkWell(
                        onTap: () => _showLeadPicker(leads, prospects),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCustomerName != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.trending_up_rounded, size: 20, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedCustomerName ?? 'Tap to select lead...',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: _selectedCustomerName != null ? FontWeight.w600 : FontWeight.w400,
                                    color: _selectedCustomerName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading leads: $e', style: const TextStyle(color: AppColors.error)),
                  ),
                ],
                const SizedBox(height: 18),

                // Task Completed Field (COMPULSARY)
                const Row(
                  children: [
                    Text(
                      'Task Completed',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _taskController,
                  maxLines: 4,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter task details (compulsory)';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Enter details of the task completed...\n(e.g., Conducted site survey, shared quotation, resolved inverter issue, completed client follow up)',
                    hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(14),
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
                      borderSide: const BorderSide(color: Color(0xFF1E1B4B), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Timestamp info banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEditing
                              ? 'Edited at: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}'
                              : 'Auto-recorded at submit: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Dialog Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1B4B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Submit Task',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final String? initialSelectedId;
  final ValueChanged<Customer> onSelected;

  const _CustomerPickerSheet({
    required this.customers,
    required this.initialSelectedId,
    required this.onSelected,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.customers;
      } else {
        _filtered = widget.customers.where((c) {
          final name = c.customerName.toLowerCase();
          final contact = (c.contactPerson ?? '').toLowerCase();
          final comp = c.companyName.toLowerCase();
          final phone = (c.phone ?? '').toLowerCase();
          return name.contains(q) || contact.contains(q) || comp.contains(q) || phone.contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: Color(0xFF1E1B4B)),
                const SizedBox(width: 10),
                const Text(
                  'Select Customer',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search customer by name, company, or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No customers found', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final c = _filtered[index];
                      final isSelected = c.id == widget.initialSelectedId;
                      final title = c.customerName.trim().isNotEmpty
                          ? c.customerName
                          : (c.contactPerson?.isNotEmpty == true ? c.contactPerson! : c.companyName);
                      final subtitle = [
                        if (c.companyName.isNotEmpty && c.companyName != title)
                          c.companyName,
                        if (c.phone != null && c.phone!.isNotEmpty) c.phone,
                      ].join(' • ');

                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF1E1B4B).withValues(alpha: 0.08),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1E1B4B).withValues(alpha: 0.1),
                          child: Text(
                            title.isNotEmpty ? title[0].toUpperCase() : 'C',
                            style: const TextStyle(color: Color(0xFF1E1B4B), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: subtitle.isNotEmpty
                            ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                            : null,
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF1E1B4B)) : null,
                        onTap: () => widget.onSelected(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProspectPickerSheet extends StatefulWidget {
  final List<Prospect> prospects;
  final String? initialSelectedName;
  final ValueChanged<Prospect> onSelected;

  const _ProspectPickerSheet({
    required this.prospects,
    required this.initialSelectedName,
    required this.onSelected,
  });

  @override
  State<_ProspectPickerSheet> createState() => _ProspectPickerSheetState();
}

class _ProspectPickerSheetState extends State<_ProspectPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Prospect> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.prospects;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.prospects;
      } else {
        _filtered = widget.prospects.where((p) {
          final name = p.name.toLowerCase();
          final phone = p.phone.toLowerCase();
          final comp = (p.company ?? '').toLowerCase();
          final addr = (p.address ?? '').toLowerCase();
          return name.contains(q) || phone.contains(q) || comp.contains(q) || addr.contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                const Text(
                  'Select Prospect',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search prospect by name, phone, city...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No prospects found', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final p = _filtered[index];
                      final isSelected = widget.initialSelectedName != null &&
                          widget.initialSelectedName!.contains(p.name);
                      final subtitle = [
                        if (p.phone.isNotEmpty) p.phone,
                        if (p.company != null && p.company!.isNotEmpty) p.company!,
                        if (p.source.isNotEmpty) p.source,
                      ].join(' • ');

                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: subtitle.isNotEmpty
                            ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                            : null,
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF2563EB)) : null,
                        onTap: () => widget.onSelected(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LeadPickerSheet extends StatefulWidget {
  final List<Lead> leads;
  final List<Prospect> prospects;
  final String? initialSelectedName;
  final void Function(Lead lead, String displayName) onSelected;

  const _LeadPickerSheet({
    required this.leads,
    required this.prospects,
    required this.initialSelectedName,
    required this.onSelected,
  });

  @override
  State<_LeadPickerSheet> createState() => _LeadPickerSheetState();
}

class _LeadPickerSheetState extends State<_LeadPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Lead> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.leads;
    _searchController.addListener(_onSearchChanged);
  }

  String _getDisplayName(Lead lead) {
    if (lead.prospectName != null && lead.prospectName!.isNotEmpty) {
      return lead.prospectName!;
    }
    final p = widget.prospects.where((p) => p.id == lead.prospectId).firstOrNull;
    if (p != null && p.name.isNotEmpty) return p.name;
    return 'Lead #${lead.id.length > 6 ? lead.id.substring(0, 6) : lead.id}';
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.leads;
      } else {
        _filtered = widget.leads.where((l) {
          final name = _getDisplayName(l).toLowerCase();
          final prod = l.productName.toLowerCase();
          final phone = (l.contactPhone ?? '').toLowerCase();
          return name.contains(q) || prod.contains(q) || phone.contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                const Text(
                  'Select Lead',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search lead by name, product, phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No leads found', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final l = _filtered[index];
                      final name = _getDisplayName(l);
                      final isSelected = widget.initialSelectedName != null &&
                          widget.initialSelectedName!.contains(name);
                      final subtitle = [
                        l.productName,
                        '₹${l.estimatedValue.toStringAsFixed(0)}',
                        if (l.contactPhone != null && l.contactPhone!.isNotEmpty) l.contactPhone!,
                        l.status,
                      ].join(' • ');

                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'L',
                            style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF7C3AED)) : null,
                        onTap: () => widget.onSelected(l, name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
