// lib/features/assigned_work/models/assigned_work_item.dart

import 'package:intl/intl.dart';

enum WorkPriority {
  low,
  medium,
  high,
  urgent;

  String get value => name;

  String get displayName {
    switch (this) {
      case WorkPriority.low:
        return 'Low';
      case WorkPriority.medium:
        return 'Medium';
      case WorkPriority.high:
        return 'High';
      case WorkPriority.urgent:
        return 'Urgent';
    }
  }

  static WorkPriority fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'low':
        return WorkPriority.low;
      case 'high':
        return WorkPriority.high;
      case 'urgent':
        return WorkPriority.urgent;
      case 'medium':
      default:
        return WorkPriority.medium;
    }
  }
}

enum WorkStatus {
  pending,
  inProgress,
  completed,
  cancelled;

  String get value {
    switch (this) {
      case WorkStatus.pending:
        return 'pending';
      case WorkStatus.inProgress:
        return 'in_progress';
      case WorkStatus.completed:
        return 'completed';
      case WorkStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case WorkStatus.pending:
        return 'Pending';
      case WorkStatus.inProgress:
        return 'In Progress';
      case WorkStatus.completed:
        return 'Completed';
      case WorkStatus.cancelled:
        return 'Cancelled';
    }
  }

  static WorkStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return WorkStatus.inProgress;
      case 'completed':
      case 'done':
        return WorkStatus.completed;
      case 'cancelled':
        return WorkStatus.cancelled;
      case 'pending':
      default:
        return WorkStatus.pending;
    }
  }
}

class AssignedWorkItem {
  final String id;
  final String title;
  final String description;
  final DateTime taskDate;
  final String? dueTime;
  final String assignedToUserId;
  final String assignedToUserName;
  final String? assignedToUserRole;
  final String assignedByUserId;
  final String assignedByUserName;
  final String? assignedByUserRole;
  final String? customerId;
  final String? customerName;
  final WorkPriority priority;
  final WorkStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTrace;
  final bool isRolledOver;
  final DateTime? displayDate;

  AssignedWorkItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.taskDate,
    this.dueTime,
    required this.assignedToUserId,
    required this.assignedToUserName,
    this.assignedToUserRole,
    required this.assignedByUserId,
    required this.assignedByUserName,
    this.assignedByUserRole,
    this.customerId,
    this.customerName,
    this.priority = WorkPriority.medium,
    this.status = WorkStatus.pending,
    this.completedAt,
    this.isTrace = false,
    this.isRolledOver = false,
    this.displayDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();


  bool get isCompleted => status == WorkStatus.completed;
  bool get isPending => status == WorkStatus.pending;

  String get formattedDate => DateFormat('dd/MM/yyyy').format(taskDate);

  String? get dueTimeFormatted {
    if (dueTime == null || dueTime!.trim().isEmpty) return null;
    final trimmed = dueTime!.trim();
    if (trimmed.toUpperCase().contains('AM') || trimmed.toUpperCase().contains('PM')) {
      return trimmed;
    }
    final parts = trimmed.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final period = hour >= 12 ? 'PM' : 'AM';
        final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final m = minute.toString().padLeft(2, '0');
        return '$h:$m $period';
      }
    }
    return trimmed;
  }

  factory AssignedWorkItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString())?.toLocal() ?? DateTime.now();
    }

    DateTime parsedTaskDate;
    if (json['task_date'] != null) {
      parsedTaskDate = parseDate(json['task_date']);
    } else if (json['completed_at'] != null) {
      parsedTaskDate = parseDate(json['completed_at']);
    } else {
      parsedTaskDate = parseDate(json['created_at']);
    }
    // Normalize to date-only
    parsedTaskDate = DateTime(parsedTaskDate.year, parsedTaskDate.month, parsedTaskDate.day);

    return AssignedWorkItem(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? json['task_description'] ?? 'Work Item').toString(),
      description: (json['description'] ?? json['task_description'] ?? '').toString(),
      taskDate: parsedTaskDate,
      dueTime: json['due_time']?.toString(),
      assignedToUserId: (json['assigned_to_user_id'] ?? json['user_id'] ?? '').toString(),
      assignedToUserName: (json['assigned_to_user_name'] ?? json['user_name'] ?? 'Unassigned').toString(),
      assignedToUserRole: json['assigned_to_user_role']?.toString() ?? json['user_role']?.toString(),
      assignedByUserId: (json['assigned_by_user_id'] ?? json['created_by'] ?? json['user_id'] ?? '').toString(),
      assignedByUserName: (json['assigned_by_user_name'] ?? json['user_name'] ?? 'Self').toString(),
      assignedByUserRole: json['assigned_by_user_role']?.toString(),
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      priority: WorkPriority.fromString(json['priority']?.toString()),
      status: WorkStatus.fromString(json['status']?.toString()),
      completedAt: json['completed_at'] != null ? parseDate(json['completed_at']) : null,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'task_date': DateFormat('yyyy-MM-dd').format(taskDate),
    if (dueTime != null && dueTime!.isNotEmpty) 'due_time': dueTime,
    'assigned_to_user_id': assignedToUserId,
    'assigned_to_user_name': assignedToUserName,
    if (assignedToUserRole != null) 'assigned_to_user_role': assignedToUserRole,
    'assigned_by_user_id': assignedByUserId,
    'assigned_by_user_name': assignedByUserName,
    if (assignedByUserRole != null) 'assigned_by_user_role': assignedByUserRole,
    if (customerId != null && customerId!.isNotEmpty) 'customer_id': customerId,
    if (customerName != null && customerName!.isNotEmpty) 'customer_name': customerName,
    'priority': priority.value,
    'status': status.value,
    if (completedAt != null) 'completed_at': completedAt!.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  AssignedWorkItem copyWith({
    String? title,
    String? description,
    DateTime? taskDate,
    String? dueTime,
    String? assignedToUserId,
    String? assignedToUserName,
    String? assignedToUserRole,
    String? assignedByUserId,
    String? assignedByUserName,
    String? assignedByUserRole,
    String? customerId,
    String? customerName,
    WorkPriority? priority,
    WorkStatus? status,
    DateTime? completedAt,
    DateTime? updatedAt,
    bool? isTrace,
    bool? isRolledOver,
    DateTime? displayDate,
  }) {
    return AssignedWorkItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      taskDate: taskDate ?? this.taskDate,
      dueTime: dueTime ?? this.dueTime,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedToUserName: assignedToUserName ?? this.assignedToUserName,
      assignedToUserRole: assignedToUserRole ?? this.assignedToUserRole,
      assignedByUserId: assignedByUserId ?? this.assignedByUserId,
      assignedByUserName: assignedByUserName ?? this.assignedByUserName,
      assignedByUserRole: assignedByUserRole ?? this.assignedByUserRole,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      isTrace: isTrace ?? this.isTrace,
      isRolledOver: isRolledOver ?? this.isRolledOver,
      displayDate: displayDate ?? this.displayDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
