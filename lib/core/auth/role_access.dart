// lib/core/auth/role_access.dart

import '../models/profile.dart';
import '../models/user_role.dart';

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

  /// Installation Module access: Installation staff, Service Head, Manager, Admin, Technician
  static bool canAccessInstallation(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.installation,
      UserRole.salesHead,
      UserRole.technician,
    ]);
  }

  /// Complaints Module access: Complaints staff, Service Head, Manager, Admin, Technician
  static bool canAccessComplaints(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
      UserRole.serviceHead,
      UserRole.complaints,
      UserRole.technician,
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
      UserRole.boq,
      UserRole.factory,
      UserRole.purchase,
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

  /// PDF Library access (List PDFs): Admin, Manager, Service Head
  static bool canAccessPdfList(dynamic profileOrRoles) {
    return hasAnyRole(profileOrRoles, [
      UserRole.admin,
      UserRole.manager,
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
