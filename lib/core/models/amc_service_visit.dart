// lib/core/models/amc_service_visit.dart

import 'package:flutter/material.dart';

enum AmcVisitStatus {
  scheduled,
  completed,
  missed,
  rescheduled;

  static AmcVisitStatus fromString(String value) {
    switch (value) {
      case 'scheduled':
        return AmcVisitStatus.scheduled;
      case 'completed':
        return AmcVisitStatus.completed;
      case 'missed':
        return AmcVisitStatus.missed;
      case 'rescheduled':
        return AmcVisitStatus.rescheduled;
      default:
        return AmcVisitStatus.scheduled;
    }
  }

  String get dbValue {
    switch (this) {
      case AmcVisitStatus.scheduled:
        return 'scheduled';
      case AmcVisitStatus.completed:
        return 'completed';
      case AmcVisitStatus.missed:
        return 'missed';
      case AmcVisitStatus.rescheduled:
        return 'rescheduled';
    }
  }

  String get displayName {
    switch (this) {
      case AmcVisitStatus.scheduled:
        return 'Scheduled';
      case AmcVisitStatus.completed:
        return 'Completed';
      case AmcVisitStatus.missed:
        return 'Missed';
      case AmcVisitStatus.rescheduled:
        return 'Rescheduled';
    }
  }

  Color get color {
    switch (this) {
      case AmcVisitStatus.scheduled:
        return const Color(0xFF3B82F6); // blue
      case AmcVisitStatus.completed:
        return const Color(0xFF22C55E); // green
      case AmcVisitStatus.missed:
        return const Color(0xFFEF4444); // red
      case AmcVisitStatus.rescheduled:
        return const Color(0xFFF59E0B); // amber
    }
  }

  IconData get icon {
    switch (this) {
      case AmcVisitStatus.scheduled:
        return Icons.calendar_today;
      case AmcVisitStatus.completed:
        return Icons.check_circle;
      case AmcVisitStatus.missed:
        return Icons.cancel;
      case AmcVisitStatus.rescheduled:
        return Icons.update;
    }
  }
}

class AmcServiceVisit {
  final String id;
  final String amcContractId;
  final int visitNumber;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final AmcVisitStatus status;
  final String? assignedTo;
  final String? serviceNotes;
  final bool customerSignoff;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final String? assignedToName;

  const AmcServiceVisit({
    required this.id,
    required this.amcContractId,
    required this.visitNumber,
    required this.scheduledDate,
    this.completedDate,
    required this.status,
    this.assignedTo,
    this.serviceNotes,
    required this.customerSignoff,
    required this.createdAt,
    required this.updatedAt,
    this.assignedToName,
  });

  factory AmcServiceVisit.fromJson(Map<String, dynamic> json) {
    // Handle joined profile data for assigned_to
    String? assigneeName;
    final profileData = json['profiles'];
    if (profileData is Map<String, dynamic>) {
      assigneeName = profileData['full_name'] as String?;
    }

    return AmcServiceVisit(
      id: json['id'] as String? ?? '',
      amcContractId: json['amc_contract_id'] as String? ?? '',
      visitNumber: json['visit_number'] as int? ?? 0,
      scheduledDate: json['scheduled_date'] != null
          ? (DateTime.tryParse(json['scheduled_date'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
      completedDate: json['completed_date'] != null
          ? DateTime.tryParse(json['completed_date'] as String? ?? '')
          : null,
      status: AmcVisitStatus.fromString(
          json['status'] as String? ?? 'scheduled'),
      assignedTo: json['assigned_to'] as String?,
      serviceNotes: json['service_notes'] as String?,
      customerSignoff: json['customer_signoff'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
      assignedToName: assigneeName,
    );
  }

  Map<String, dynamic> toJson() => {
        'amc_contract_id': amcContractId,
        'visit_number': visitNumber,
        'scheduled_date': scheduledDate.toIso8601String().split('T').first,
        'completed_date': completedDate?.toIso8601String().split('T').first,
        'status': status.dbValue,
        'assigned_to': assignedTo,
        'service_notes': serviceNotes,
        'customer_signoff': customerSignoff,
      };

  AmcServiceVisit copyWith({
    AmcVisitStatus? status,
    DateTime? completedDate,
    String? serviceNotes,
    bool? customerSignoff,
    String? assignedTo,
    DateTime? scheduledDate,
  }) {
    return AmcServiceVisit(
      id: id,
      amcContractId: amcContractId,
      visitNumber: visitNumber,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      serviceNotes: serviceNotes ?? this.serviceNotes,
      customerSignoff: customerSignoff ?? this.customerSignoff,
      createdAt: createdAt,
      updatedAt: updatedAt,
      assignedToName: assignedToName,
    );
  }

  bool get isPending => status == AmcVisitStatus.scheduled;
  bool get isDone => status == AmcVisitStatus.completed;
  bool get isOverdue =>
      status == AmcVisitStatus.scheduled &&
      scheduledDate.isBefore(DateTime.now());
}
