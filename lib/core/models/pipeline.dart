// lib/core/models/pipeline.dart

import 'dart:convert';
import 'customer.dart';
import 'product.dart';
import 'profile.dart';
import 'quotation.dart';
import 'sales_order.dart';
import 'boq.dart';
import 'factory_order.dart';
import 'purchase_order.dart';

class SalesPipeline {
  final String id;
  final String? dealId;
  final String customerId;
  final String productId;
  final String createdBy;
  final PipelineStep _dbCurrentStep;
  final PipelineStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  final List<Map<String, dynamic>>? stepsConfig;

  // Joined data
  final Customer? customer;
  final Product? product;
  final Profile? createdByProfile;
  final Quotation? quotation;
  final SalesOrder? salesOrder;
  final Boq? boq;
  final List<Boq> allBoqs;
  final FactoryOrder? factoryOrder;
  final PurchaseOrder? purchaseOrder;

  /// Returns the human-readable deal ID (e.g. 'DEAL-26-27-0001').
  String get displayDealId => (dealId != null && dealId!.trim().isNotEmpty) ? dealId!.trim() : '';

  /// Returns the main base quotation number without revision suffix (e.g. 'IZY/QT/26-27/0237').
  String get baseQuotationNumber => quotation != null ? quotation!.baseQuotationNumber : '';

  const SalesPipeline({
    required this.id,
    this.dealId,
    required this.customerId,
    required this.productId,
    required this.createdBy,
    required PipelineStep currentStep,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.stepsConfig,
    this.customer,
    this.product,
    this.createdByProfile,
    this.quotation,
    this.salesOrder,
    this.boq,
    this.allBoqs = const [],
    this.factoryOrder,
    this.purchaseOrder,
  }) : _dbCurrentStep = currentStep;

  factory SalesPipeline.fromJson(Map<String, dynamic> json) {
    final customerData = json['customers'] ?? json['customers!sales_pipelines_customer_id_fkey'];
    final productData = json['products'] ?? json['products!sales_pipelines_product_id_fkey'];
    final profileData = json['profiles'] ?? json['profiles!sales_pipelines_created_by_fkey'];

    return SalesPipeline(
      id: json['id'] as String? ?? '',
      dealId: json['deal_id'] as String?,
      customerId: json['customer_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? '',
      currentStep: PipelineStep.fromString(json['current_step'] as String? ?? 'quotation'),
      status: PipelineStatus.fromString(json['status'] as String? ?? 'in_progress'),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String? ?? '')
          : null,
      stepsConfig: json['steps_config'] != null
          ? List<Map<String, dynamic>>.from(
              (json['steps_config'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : null,
      customer: customerData != null
          ? Customer.fromJson(customerData as Map<String, dynamic>)
          : null,
      product: productData != null
          ? Product.fromJson(productData as Map<String, dynamic>)
          : null,
      createdByProfile: profileData != null
          ? Profile.fromJson(profileData as Map<String, dynamic>)
          : null,
      quotation: json['quotations'] != null
          ? (json['quotations'] is List
              ? ((json['quotations'] as List).isNotEmpty
                  ? Quotation.fromJson((json['quotations'] as List).first as Map<String, dynamic>)
                  : null)
              : Quotation.fromJson(json['quotations'] as Map<String, dynamic>))
          : null,
      salesOrder: json['sales_orders'] != null
          ? (json['sales_orders'] is List
              ? ((json['sales_orders'] as List).isNotEmpty
                  ? SalesOrder.fromJson((json['sales_orders'] as List).first as Map<String, dynamic>)
                  : null)
              : SalesOrder.fromJson(json['sales_orders'] as Map<String, dynamic>))
          : null,
      allBoqs: json['boqs'] != null
          ? (json['boqs'] is List
              ? (json['boqs'] as List)
                  .where((e) => e is Map)
                  .map((e) => Boq.fromJson(e as Map<String, dynamic>))
                  .toList()
              : [Boq.fromJson(json['boqs'] as Map<String, dynamic>)])
          : const [],
      boq: json['boqs'] != null
          ? (json['boqs'] is List
              ? ((json['boqs'] as List).isNotEmpty
                  ? Boq.fromJson((json['boqs'] as List).first as Map<String, dynamic>)
                  : null)
              : Boq.fromJson(json['boqs'] as Map<String, dynamic>))
          : null,
      factoryOrder: json['factory_orders'] != null
          ? (json['factory_orders'] is List
              ? ((json['factory_orders'] as List).isNotEmpty
                  ? FactoryOrder.fromJson((json['factory_orders'] as List).first as Map<String, dynamic>)
                  : null)
              : FactoryOrder.fromJson(json['factory_orders'] as Map<String, dynamic>))
          : null,
      purchaseOrder: json['purchase_orders'] != null
          ? (json['purchase_orders'] is List
              ? ((json['purchase_orders'] as List).isNotEmpty
                  ? PurchaseOrder.fromJson((json['purchase_orders'] as List).first as Map<String, dynamic>)
                  : null)
              : PurchaseOrder.fromJson(json['purchase_orders'] as Map<String, dynamic>))
          : null,
    );
  }

  SalesPipeline copyWith({
    String? dealId,
    PipelineStep? currentStep,
    PipelineStatus? status,
    String? notes,
    List<Boq>? allBoqs,
  }) {
    return SalesPipeline(
      id: id,
      dealId: dealId ?? this.dealId,
      customerId: customerId,
      productId: productId,
      createdBy: createdBy,
      currentStep: currentStep ?? _dbCurrentStep,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      stepsConfig: stepsConfig,
      customer: customer,
      product: product,
      createdByProfile: createdByProfile,
      quotation: quotation,
      salesOrder: salesOrder,
      boq: boq,
      allBoqs: allBoqs ?? this.allBoqs,
      factoryOrder: factoryOrder,
      purchaseOrder: purchaseOrder,
    );
  }

  List<String> get skippedSteps {
    if (notes == null || !notes!.contains('[WORK_PROGRESS:')) return const [];
    try {
      final start = notes!.indexOf('[WORK_PROGRESS:') + '[WORK_PROGRESS:'.length;
      int end = notes!.indexOf(':WORK_PROGRESS]', start);
      if (end == -1) end = notes!.lastIndexOf(']');
      if (end != -1 && end > start) {
        final parsed = jsonDecode(notes!.substring(start, end));
        if (parsed is Map && parsed['skipped_steps'] is List) {
          return List<String>.from((parsed['skipped_steps'] as List).map((e) => e.toString()));
        }
      }
    } catch (_) {}
    return const [];
  }

  bool isStepSkipped(String stepKey) => skippedSteps.contains(stepKey);

  PipelineStep get currentStep {
    if (status == PipelineStatus.completed) {
      return PipelineStep.completed;
    }
    final skipped = skippedSteps;
    final boqSkipped = skipped.contains('boq');
    final foSkipped = skipped.contains('factory_order');
    final poSkipped = skipped.contains('purchase_order');

    final bool poDone = purchaseOrder != null &&
        (purchaseOrder!.status == PurchaseOrderStatus.ordered ||
            purchaseOrder!.status == PurchaseOrderStatus.received);
    final bool foDone = factoryOrder != null &&
        factoryOrder!.status == FactoryOrderStatus.completed;
    final bool boqDone = boq != null && boq!.status == BoqStatus.submitted;
    final bool soDone = salesOrder != null && salesOrder!.status == SalesOrderStatus.confirmed;
    final bool qDone = quotation != null && quotation!.status == QuotationStatus.confirmed;

    if (poDone || (poSkipped && (foDone || foSkipped) && (boqDone || boqSkipped) && soDone)) {
      return PipelineStep.completed;
    }
    if (foDone || (foSkipped && (boqDone || boqSkipped) && soDone)) {
      return PipelineStep.purchaseOrder;
    }
    if (boqDone || (boqSkipped && soDone)) {
      return PipelineStep.factoryOrder;
    }
    if (soDone) {
      return PipelineStep.boq;
    }
    if (qDone) {
      return PipelineStep.salesOrder;
    }
    return _dbCurrentStep;
  }

  bool get isActive =>
      status == PipelineStatus.inProgress || status == PipelineStatus.onHold;

  bool get canProceedToBoq =>
      currentStep.stepIndex >= PipelineStep.boq.stepIndex;
  bool get canProceedToFactory =>
      currentStep.stepIndex >= PipelineStep.factoryOrder.stepIndex;
  bool get canProceedToPurchase =>
      currentStep.stepIndex >= PipelineStep.purchaseOrder.stepIndex;
}
