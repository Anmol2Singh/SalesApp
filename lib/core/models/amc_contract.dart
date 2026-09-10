// lib/core/models/amc_contract.dart

import 'package:flutter/material.dart';
import 'customer.dart';
import 'product.dart';
import 'profile.dart';
import 'amc_service_visit.dart';

enum AmcContractStatus {
  interested,
  pendingSetup,
  active,
  expiringSoon,
  expired,
  cancelled;

  static AmcContractStatus fromString(String value) {
    switch (value) {
      case 'interested':
        return AmcContractStatus.interested;
      case 'pending_setup':
        return AmcContractStatus.pendingSetup;
      case 'active':
        return AmcContractStatus.active;
      case 'expiring_soon':
        return AmcContractStatus.expiringSoon;
      case 'expired':
        return AmcContractStatus.expired;
      case 'cancelled':
        return AmcContractStatus.cancelled;
      default:
        return AmcContractStatus.interested;
    }
  }

  String get dbValue {
    switch (this) {
      case AmcContractStatus.interested:
        return 'interested';
      case AmcContractStatus.pendingSetup:
        return 'pending_setup';
      case AmcContractStatus.active:
        return 'active';
      case AmcContractStatus.expiringSoon:
        return 'expiring_soon';
      case AmcContractStatus.expired:
        return 'expired';
      case AmcContractStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case AmcContractStatus.interested:
        return 'Interested';
      case AmcContractStatus.pendingSetup:
        return 'Pending Setup';
      case AmcContractStatus.active:
        return 'Active';
      case AmcContractStatus.expiringSoon:
        return 'Expiring Soon';
      case AmcContractStatus.expired:
        return 'Expired';
      case AmcContractStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case AmcContractStatus.interested:
      case AmcContractStatus.pendingSetup:
        return const Color(0xFF94A3B8); // grey
      case AmcContractStatus.active:
        return const Color(0xFF22C55E); // green
      case AmcContractStatus.expiringSoon:
        return const Color(0xFFF59E0B); // amber
      case AmcContractStatus.expired:
        return const Color(0xFFEF4444); // red
      case AmcContractStatus.cancelled:
        return const Color(0xFF64748B); // dark grey
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AmcContractStatus.interested:
      case AmcContractStatus.pendingSetup:
        return const Color(0xFFF1F5F9);
      case AmcContractStatus.active:
        return const Color(0xFFDCFCE7);
      case AmcContractStatus.expiringSoon:
        return const Color(0xFFFEF3C7);
      case AmcContractStatus.expired:
        return const Color(0xFFFEE2E2);
      case AmcContractStatus.cancelled:
        return const Color(0xFFF1F5F9);
    }
  }

  bool get isTerminal =>
      this == AmcContractStatus.expired || this == AmcContractStatus.cancelled;
}

class AmcContract {
  final String id;
  final String customerId;
  final String? pipelineId;
  final String productId;
  final String amcNumber;
  final AmcContractStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? contractAmount;
  final int? numberOfVisitsIncluded;
  final String? termsText;
  final String? pdfUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final Customer? customer;
  final Product? product;
  final Profile? createdByProfile;
  final List<AmcServiceVisit>? serviceVisits;

  const AmcContract({
    required this.id,
    required this.customerId,
    this.pipelineId,
    required this.productId,
    required this.amcNumber,
    required this.status,
    this.startDate,
    this.endDate,
    this.contractAmount,
    this.numberOfVisitsIncluded,
    this.termsText,
    this.pdfUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.product,
    this.createdByProfile,
    this.serviceVisits,
  });

  factory AmcContract.fromJson(Map<String, dynamic> json) {
    final customerData =
        json['customers'] ?? json['customers!amc_contracts_customer_id_fkey'];
    final productData =
        json['products'] ?? json['products!amc_contracts_product_id_fkey'];
    final profileData =
        json['profiles'] ?? json['profiles!amc_contracts_created_by_fkey'];

    List<AmcServiceVisit>? visits;
    if (json['amc_service_visits'] != null) {
      final visitsList = json['amc_service_visits'] as List<dynamic>;
      visits = visitsList
          .map((v) => AmcServiceVisit.fromJson(v as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
    }

    return AmcContract(
      id: json['id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String?,
      productId: json['product_id'] as String? ?? '',
      amcNumber: json['amc_number'] as String? ?? '',
      status: AmcContractStatus.fromString(
          json['status'] as String? ?? 'interested'),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String? ?? '')
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String? ?? '')
          : null,
      contractAmount: json['contract_amount'] != null
          ? (json['contract_amount'] is num
              ? (json['contract_amount'] as num).toDouble()
              : double.tryParse(json['contract_amount'].toString()))
          : null,
      numberOfVisitsIncluded: json['number_of_visits_included'] as int?,
      termsText: json['terms_text'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
      customer: customerData != null
          ? Customer.fromJson(customerData as Map<String, dynamic>)
          : null,
      product: productData != null
          ? Product.fromJson(productData as Map<String, dynamic>)
          : null,
      createdByProfile: profileData != null
          ? Profile.fromJson(profileData as Map<String, dynamic>)
          : null,
      serviceVisits: visits,
    );
  }

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'pipeline_id': pipelineId,
        'product_id': productId,
        'status': status.dbValue,
        'start_date': startDate?.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'contract_amount': contractAmount,
        'number_of_visits_included': numberOfVisitsIncluded,
        'terms_text': termsText,
        'pdf_url': pdfUrl,
        'created_by': createdBy,
      };

  AmcContract copyWith({
    AmcContractStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    double? contractAmount,
    int? numberOfVisitsIncluded,
    String? termsText,
    String? pdfUrl,
    List<AmcServiceVisit>? serviceVisits,
  }) {
    return AmcContract(
      id: id,
      customerId: customerId,
      pipelineId: pipelineId,
      productId: productId,
      amcNumber: amcNumber,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      contractAmount: contractAmount ?? this.contractAmount,
      numberOfVisitsIncluded:
          numberOfVisitsIncluded ?? this.numberOfVisitsIncluded,
      termsText: termsText ?? this.termsText,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      customer: customer,
      product: product,
      createdByProfile: createdByProfile,
      serviceVisits: serviceVisits ?? this.serviceVisits,
    );
  }

  // Computed helpers
  int get visitsCompleted =>
      serviceVisits
          ?.where((v) => v.status == AmcVisitStatus.completed)
          .length ??
      0;

  int get totalVisits => numberOfVisitsIncluded ?? serviceVisits?.length ?? 0;

  String get visitsProgressText => '$visitsCompleted of $totalVisits done';

  DateTime? get nextVisitDate {
    if (serviceVisits == null || serviceVisits!.isEmpty) return null;
    final scheduled = serviceVisits!
        .where((v) => v.status == AmcVisitStatus.scheduled)
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return scheduled.isNotEmpty ? scheduled.first.scheduledDate : null;
  }

  bool get isExpiringSoon => status == AmcContractStatus.expiringSoon;
  bool get isActive => status == AmcContractStatus.active;
  bool get canBeFinalized =>
      status == AmcContractStatus.interested ||
      status == AmcContractStatus.pendingSetup;
  bool get canBeRenewed =>
      status == AmcContractStatus.expiringSoon ||
      status == AmcContractStatus.expired;
}
