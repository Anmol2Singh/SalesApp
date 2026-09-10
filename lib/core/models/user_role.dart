// lib/core/models/user_role.dart

import 'package:flutter/material.dart';

enum UserRole {
  admin,
  manager,
  sales,
  salesHead,
  factory,
  purchase,
  boq,
  serviceHead,
  technician,
  customer,
  crmStaff;

  static UserRole fromString(String value) {
    switch (value) {
      case 'admin': return UserRole.admin;
      case 'manager': return UserRole.manager;
      case 'sales': return UserRole.sales;
      case 'sales_head': return UserRole.salesHead;
      case 'service_head': return UserRole.serviceHead;
      case 'factory': return UserRole.factory;
      case 'purchase': return UserRole.purchase;
      case 'boq': return UserRole.boq;
      case 'technician': return UserRole.technician;
      case 'customer': return UserRole.customer;
      case 'crm_staff': return UserRole.crmStaff;
      default: return UserRole.customer;
    }
  }

  String get value {
    switch (this) {
      case UserRole.admin: return 'admin';
      case UserRole.manager: return 'manager';
      case UserRole.sales: return 'sales';
      case UserRole.salesHead: return 'sales_head';
      case UserRole.serviceHead: return 'service_head';
      case UserRole.factory: return 'factory';
      case UserRole.purchase: return 'purchase';
      case UserRole.boq: return 'boq';
      case UserRole.technician: return 'technician';
      case UserRole.customer: return 'customer';
      case UserRole.crmStaff: return 'crm_staff';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.sales:
        return 'Sales Executive';
      case UserRole.salesHead:
        return 'Sales Head';
      case UserRole.serviceHead:
        return 'Service Coordinator';
      case UserRole.factory:
        return 'Factory Staff';
      case UserRole.purchase:
        return 'Material Acquisition Staff';
      case UserRole.boq:
        return 'BOQ Staff';
      case UserRole.technician:
        return 'Technician';
      case UserRole.customer:
        return 'Customer';
      case UserRole.crmStaff:
        return 'CRM Staff';
    }
  }

  bool get canViewAllCustomers => canViewAllPipelines || this == UserRole.technician || this == UserRole.crmStaff;

  bool get canViewAllPipelines =>
      this == UserRole.admin ||
      this == UserRole.manager ||
      this == UserRole.salesHead ||
      this == UserRole.serviceHead ||
      this == UserRole.factory ||
      this == UserRole.purchase ||
      this == UserRole.boq;
  bool get canCreateCustomers => this == UserRole.sales || this == UserRole.admin || this == UserRole.manager || this == UserRole.salesHead;
  bool get canEditCustomers => this == UserRole.sales || this == UserRole.admin || this == UserRole.manager || this == UserRole.salesHead || this == UserRole.crmStaff;
  bool get canConfirmQuotations => this == UserRole.sales || this == UserRole.admin || this == UserRole.manager || this == UserRole.salesHead || this == UserRole.serviceHead;
  bool get canApproveQuotations => this == UserRole.admin || this == UserRole.manager || this == UserRole.serviceHead || this == UserRole.salesHead;
  bool get canManageUsers => this == UserRole.admin || this == UserRole.manager;
  bool get canManageCatalog => this == UserRole.admin || this == UserRole.manager;
  bool get canViewFactoryQueue => this == UserRole.factory || this == UserRole.admin || this == UserRole.manager;
  bool get canViewPurchaseQueue => this == UserRole.purchase || this == UserRole.admin || this == UserRole.manager;
  bool get canExportAll => this == UserRole.admin || this == UserRole.manager;
  bool get canViewCustomerPersonalData =>
      this == UserRole.admin ||
      this == UserRole.manager ||
      this == UserRole.sales ||
      this == UserRole.salesHead ||
      this == UserRole.serviceHead ||
      this == UserRole.crmStaff;
  bool get canActivateWarrantyCard =>
      this == UserRole.admin ||
      this == UserRole.manager ||
      this == UserRole.serviceHead;

  bool get canAccessCrm =>
      this == UserRole.admin ||
      this == UserRole.manager ||
      this == UserRole.sales ||
      this == UserRole.salesHead ||
      this == UserRole.crmStaff ||
      this == UserRole.boq ||
      this == UserRole.factory ||
      this == UserRole.purchase;

  bool get isSalesOrAdmin =>
      this == UserRole.admin ||
      this == UserRole.manager ||
      this == UserRole.sales ||
      this == UserRole.salesHead;

  Color get roleColor {
    switch (this) {
      case UserRole.admin:
        return const Color(0xFF6366F1); // Indigo
      case UserRole.manager:
        return const Color(0xFF8B5CF6); // Purple
      case UserRole.sales:
        return const Color(0xFF06B6D4); // Cyan
      case UserRole.salesHead:
        return const Color(0xFF0EA5E9); // Sky Blue
      case UserRole.serviceHead:
        return const Color(0xFF3B82F6); // Blue
      case UserRole.factory:
        return const Color(0xFFF59E0B); // Amber/Orange
      case UserRole.purchase:
        return const Color(0xFF10B981); // Emerald
      case UserRole.boq:
        return const Color(0xFFEC4899); // Pink
      case UserRole.technician:
        return const Color(0xFF14B8A6); // Teal
      case UserRole.crmStaff:
        return const Color(0xFF8B5CF6); // Violet
      case UserRole.customer:
        return const Color(0xFF64748B); // Slate
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case UserRole.admin:
        return const [Color(0xFF4F46E5), Color(0xFF7C3AED)];
      case UserRole.manager:
        return const [Color(0xFF7C3AED), Color(0xFFC026D3)];
      case UserRole.sales:
        return const [Color(0xFF0284C7), Color(0xFF06B6D4)];
      case UserRole.salesHead:
        return const [Color(0xFF0369A1), Color(0xFF0EA5E9)];
      case UserRole.serviceHead:
        return const [Color(0xFF1D4ED8), Color(0xFF3B82F6)];
      case UserRole.factory:
        return const [Color(0xFFD97706), Color(0xFFF59E0B)];
      case UserRole.purchase:
        return const [Color(0xFF059669), Color(0xFF10B981)];
      case UserRole.boq:
        return const [Color(0xFFDB2777), Color(0xFFEC4899)];
      case UserRole.technician:
        return const [Color(0xFF0D9488), Color(0xFF14B8A6)];
      case UserRole.crmStaff:
        return const [Color(0xFF6D28D9), Color(0xFF8B5CF6)];
      case UserRole.customer:
        return const [Color(0xFF475569), Color(0xFF64748B)];
    }
  }
}
