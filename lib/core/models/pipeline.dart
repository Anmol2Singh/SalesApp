// lib/core/models/pipeline.dart

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
  final FactoryOrder? factoryOrder;
  final PurchaseOrder? purchaseOrder;

  const SalesPipeline({
    required this.id,
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
    this.factoryOrder,
    this.purchaseOrder,
  }) : _dbCurrentStep = currentStep;

  factory SalesPipeline.fromJson(Map<String, dynamic> json) {
    final customerData = json['customers'] ?? json['customers!sales_pipelines_customer_id_fkey'];
    final productData = json['products'] ?? json['products!sales_pipelines_product_id_fkey'];
    final profileData = json['profiles'] ?? json['profiles!sales_pipelines_created_by_fkey'];

    return SalesPipeline(
      id: json['id'] as String? ?? '',
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
    PipelineStep? currentStep,
    PipelineStatus? status,
    String? notes,
  }) {
    return SalesPipeline(
      id: id,
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
      factoryOrder: factoryOrder,
      purchaseOrder: purchaseOrder,
    );
  }

  PipelineStep get currentStep {
    if (status == PipelineStatus.completed) {
      return PipelineStep.completed;
    }
    if (purchaseOrder != null &&
        (purchaseOrder!.status == PurchaseOrderStatus.ordered ||
            purchaseOrder!.status == PurchaseOrderStatus.received)) {
      return PipelineStep.completed;
    }
    if (factoryOrder != null &&
        factoryOrder!.status == FactoryOrderStatus.completed) {
      return PipelineStep.purchaseOrder;
    }
    if (boq != null && boq!.status == BoqStatus.submitted) {
      return PipelineStep.factoryOrder;
    }
    if (salesOrder != null && salesOrder!.status == SalesOrderStatus.confirmed) {
      return PipelineStep.boq;
    }
    if (quotation != null && quotation!.status == QuotationStatus.confirmed) {
      return PipelineStep.salesOrder;
    }
    if (quotation == null &&
        salesOrder == null &&
        boq == null &&
        factoryOrder == null &&
        purchaseOrder == null) {
      return PipelineStep.quotation;
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
