// lib/core/models/notification.dart

enum NotificationType {
  stepUnlocked,
  assigned,
  reminder,
  adminAlert,
  amcVisitDueSoon,
  amcVisitMissed,
  amcExpiringSoon,
  amcExpired;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'step_unlocked':
        return NotificationType.stepUnlocked;
      case 'assigned':
        return NotificationType.assigned;
      case 'reminder':
        return NotificationType.reminder;
      case 'admin_alert':
        return NotificationType.adminAlert;
      case 'amc_visit_due_soon':
        return NotificationType.amcVisitDueSoon;
      case 'amc_visit_missed':
        return NotificationType.amcVisitMissed;
      case 'amc_expiring_soon':
        return NotificationType.amcExpiringSoon;
      case 'amc_expired':
        return NotificationType.amcExpired;
      default:
        return NotificationType.adminAlert;
    }
  }

  bool get isAmcRelated =>
      this == NotificationType.amcVisitDueSoon ||
      this == NotificationType.amcVisitMissed ||
      this == NotificationType.amcExpiringSoon ||
      this == NotificationType.amcExpired;
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? relatedPipelineId;
  final String? relatedAmcId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedPipelineId,
    this.relatedAmcId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      relatedPipelineId: json['related_pipeline_id'] as String?,
      relatedAmcId: json['related_amc_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      relatedPipelineId: relatedPipelineId,
      relatedAmcId: relatedAmcId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
