// lib/features/daily_tasks/models/daily_task_model.dart

class DailyTask {
  final String id;
  final String? customerId;
  final String customerName;
  final String? userId;
  final String userName;
  final String userRole;
  final String taskDescription;
  final DateTime completedAt;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyTask({
    required this.id,
    this.customerId,
    required this.customerName,
    this.userId,
    required this.userName,
    required this.userRole,
    required this.taskDescription,
    required this.completedAt,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deletedByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'] as String? ?? '',
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ?? 'Unknown Customer',
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String? ?? 'Staff Member',
      userRole: json['user_role'] as String? ?? 'staff',
      taskDescription: json['task_description'] as String? ?? '',
      completedAt: json['completed_at'] != null
          ? (DateTime.tryParse(json['completed_at'] as String? ?? '')?.toLocal() ?? DateTime.now())
          : (DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now()),
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'] as String? ?? '')?.toLocal()
          : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String? ?? '')?.toLocal()
          : null,
      deletedBy: json['deleted_by'] as String?,
      deletedByName: json['deleted_by_name'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'customer_name': customerName,
    'user_id': userId,
    'user_name': userName,
    'user_role': userRole,
    'task_description': taskDescription,
    'completed_at': completedAt.toUtc().toIso8601String(),
    'is_edited': isEdited,
    'edited_at': editedAt?.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
    'deleted_by': deletedBy,
    'deleted_by_name': deletedByName,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  DailyTask copyWith({
    String? customerId,
    String? customerName,
    String? taskDescription,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedByName,
  }) {
    return DailyTask(
      id: id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      userId: userId,
      userName: userName,
      userRole: userRole,
      taskDescription: taskDescription ?? this.taskDescription,
      completedAt: completedAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deletedByName: deletedByName ?? this.deletedByName,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
