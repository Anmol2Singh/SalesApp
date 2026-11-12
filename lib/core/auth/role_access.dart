// lib/core/auth/role_access.dart

import '../models/profile.dart';
import '../models/user_role.dart';
import '../models/pipeline.dart';
import '../models/customer.dart';

/// Centralized Role & Permission Access Helper
/// Defines module-level capabilities across the app.
class RoleAccess {
  static List<UserRole> _roles(dynamic profileOrRoles) {
    if (profileOrRoles == null) return const [];
    if (profileOrRoles is Profile) {
      if (profileOrRoles.roles.isNotEmpty) return profileOrRoles.roles;
      return [profileOrRoles.primaryRole];
    }
    if (profileOrRoles is Iterable<UserRole>) {
      return profileOrRoles.toList();
    }
    if (profileOrRoles is UserRole) {
      return [profileOrRoles];
    }
    return const [];
  }

  /// Returns true if the user has Service Head role.
  static bool isServiceHead(dynamic profileOrRoles) {
    return _roles(profileOrRoles).contains(UserRole.serviceHead);
  }

  /// Returns true if user has any of the specified roles or is an Admin.
  static bool hasAnyRole(dynamic profileOrRoles, List<UserRole> targetRoles) {
    final roles = _roles(profileOrRoles);
    if (roles.contains(UserRole.admin)) return true;
    return roles.any((r) => targetRoles.contains(r));
  }

  /// Installation Module access: Installation staff, Service Head, Manager, Admin
  static bool canAccessInstallation(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.installation,
      UserRole.salesHead,
    ]);
  }

  /// Complaints Module access: Complaints staff, Service Head, Manager, Admin
  static bool canAccessComplaints(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.complaints,
    ]);
  }

  /// BOQ Module access: BOQ staff, Service Head, Admin, Manager, Sales Head, Sales, Factory
  static bool canAccessBoq(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.boq,
      UserRole.salesHead,
      UserRole.sales,
      UserRole.factory,
    ]);
  }

  /// CRM Module access: CRM Staff, Sales, Sales Head, Service Head, Manager, Admin
  static bool canAccessCrm(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.salesHead,
      UserRole.sales,
      UserRole.crmStaff,
    ]);
  }

  /// Quotation & Sales Order view access: Admins, Sales Head, Sales Executive, Manager, Service Head, BOQ
  static bool canViewQuotationAndSalesOrder(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.salesHead,
      UserRole.sales,
      UserRole.serviceHead,
      UserRole.boq,
    ]);
  }

  /// Site Track management (Material Ready / Dispatched): Sales Head and Admin
  static bool canManageSiteTrack(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.salesHead,
    ]);
  }

  /// Factory Track management (Factory Ready / Dispatched): Factory staff and Admin
  static bool canManageFactoryTrack(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.factory,
    ]);
  }

  /// Delivery Challan generation: Admin and Sales Head
  static bool canGenerateDeliveryChallan(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.salesHead,
    ]);
  }

  /// Reports access: Daily tasks, User activity report, Customer report, Analytics, Excel/PDF exports
  static bool canViewAllReports(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.salesHead,
      UserRole.accounts,
    ]);
  }

  /// PDF Library access (List PDFs): Admin, Manager, Sales Head, Service Head
  static bool canAccessPdfList(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.salesHead,
      UserRole.serviceHead,
    ]);
  }

  /// Search PDF access: Admin, Manager, Sales Head, Service Head
  static bool canSearchPdf(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.salesHead,
    ]);
  }

  /// Full access to PDF Library hub
  static bool canAccessPdfLibrary(dynamic profileOrRoles) {
    return canAccessPdfList(profileOrRoles) || canSearchPdf(profileOrRoles);
  }

  /// Warranty card activation
  static bool canActivateWarranty(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.serviceHead,
    ]);
  }

  /// Pipelines/Deals access
  static bool canViewPipelines(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.salesHead,
      UserRole.sales,
      UserRole.serviceHead,
      UserRole.installation,
      UserRole.factory,
      UserRole.purchase,
      UserRole.boq,
    ]);
  }

  /// Whether a specific deal is visible to a user given their roles & profile.
  /// For service roles (serviceHead, installation, complaints), deals start to show up
  /// when they reach the BOQ step.
  static bool isDealVisibleForUser(SalesPipeline p, Profile? profile) {
    if (profile == null) return false;
    final roles = profile.roles.isNotEmpty ? profile.roles : [profile.primaryRole];

    // Admin, Manager, Sales Head can view all deals at all stages
    if (roles.contains(UserRole.admin) ||
        roles.contains(UserRole.manager) ||
        roles.contains(UserRole.salesHead)) {
      return true;
    }

    final isCompleted = p.status == PipelineStatus.completed ||
        p.currentStep == PipelineStep.completed;

    // Service roles (serviceHead, installation, complaints) encompass BOQ capabilities.
    // Deals for service roles start showing up when they reach BOQ.
    final hasBoqOrServiceRole = roles.contains(UserRole.boq) ||
        roles.contains(UserRole.serviceHead) ||
        roles.contains(UserRole.installation) ||
        roles.contains(UserRole.complaints);

    final hasFactoryRole = roles.contains(UserRole.factory);
    final hasPurchaseRole = roles.contains(UserRole.purchase);
    final hasSalesRole = roles.contains(UserRole.sales);

    // If deal is completed, all operational/service/purchase/factory/boq/sales roles can view it
    if (isCompleted &&
        (hasBoqOrServiceRole || hasFactoryRole || hasPurchaseRole || hasSalesRole)) {
      return true;
    }

    final stepIndex = p.currentStep.stepIndex;

    // 1. BOQ / Service role: visible from BOQ step onwards (BOQ, Factory Order, Purchase Order)
    if (hasBoqOrServiceRole && stepIndex >= PipelineStep.boq.stepIndex) {
      return true;
    }

    // 2. Factory role: visible from Factory Order step onwards (Factory Order, Purchase Order)
    if (hasFactoryRole && stepIndex >= PipelineStep.factoryOrder.stepIndex) {
      return true;
    }

    // 3. Purchase role: visible from Purchase Order step onwards (Purchase Order)
    if (hasPurchaseRole && stepIndex >= PipelineStep.purchaseOrder.stepIndex) {
      return true;
    }

    // 4. Sales role: visible if created by this salesperson or assigned to them
    if (hasSalesRole) {
      if (p.createdBy == profile.id || p.customer?.assignedTo == profile.id) {
        return true;
      }
    }

    return false;
  }

  /// Customers access
  static bool canViewCustomers(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.salesHead,
      UserRole.serviceHead,
      UserRole.sales,
      UserRole.crmStaff,
      UserRole.accounts,
      UserRole.installation,
      UserRole.technician,
    ]);
  }

  // --- STRICT ADMIN-ONLY RESTRICTIONS ---
  // Service Head must NOT have access to these areas:

  /// User management (Admin panel)
  static bool canManageUsers(dynamic profileOrRoles) {
    final roles = _roles(profileOrRoles);
    return roles.contains(UserRole.admin);
  }

  /// Product Catalog management & Add Product
  static bool canManageCatalog(dynamic profileOrRoles) {
    final roles = _roles(profileOrRoles);
    return roles.contains(UserRole.admin);
  }

  /// Admin PDF Templates & settings
  static bool canManagePdfTemplates(dynamic profileOrRoles) {
    final roles = _roles(profileOrRoles);
    return roles.contains(UserRole.admin);
  }

  /// Admin Configuration
  static bool canManageConfiguration(dynamic profileOrRoles) {
    final roles = _roles(profileOrRoles);
    return roles.contains(UserRole.admin);
  }
}
