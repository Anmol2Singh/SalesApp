// lib/core/services/record_edit_permissions.dart
import '../models/user_role.dart';

enum RecordFieldType {
  name,
  phone,
  other,
}

class RecordEditPermissions {
  /// Check if the user has any edit access to the record at all.
  static bool canEditRecord({
    required UserRole? userRole,
    required List<UserRole> allRoles,
    required String? currentUserId,
    required String creatorId,
    String? assigneeId,
  }) {
    if (currentUserId == null) return false;

    // Admin or manager users can edit any record
    final isAdmin = userRole == UserRole.admin ||
        userRole == UserRole.manager ||
        allRoles.contains(UserRole.admin) ||
        allRoles.contains(UserRole.manager);
    if (isAdmin) return true;

    // Creator can edit
    if (currentUserId == creatorId) return true;

    // Assignee can edit (subject to field restrictions)
    if (assigneeId != null && currentUserId == assigneeId) return true;

    return false;
  }

  /// Check whether a specific field on the record is editable by the current user.
  /// Rule:
  /// - Admin users can always edit everything.
  /// - The creator can edit everything in full.
  /// - An assignee can edit everything EXCEPT customer's name and phone number.
  /// - Non-creator non-assignee non-admins cannot edit anything.
  static bool canEditField({
    required String fieldName,
    required UserRole? userRole,
    required List<UserRole> allRoles,
    required String? currentUserId,
    required String creatorId,
    String? assigneeId,
  }) {
    if (currentUserId == null) return false;

    final isAdmin = userRole == UserRole.admin ||
        userRole == UserRole.manager ||
        allRoles.contains(UserRole.admin) ||
        allRoles.contains(UserRole.manager);
    if (isAdmin) return true;

    final isCreator = currentUserId == creatorId;
    if (isCreator) return true;

    final isAssignee = assigneeId != null && currentUserId == assigneeId;
    if (isAssignee) {
      final normalized = fieldName.trim().toLowerCase();
      // Assignee cannot edit name and phone number
      if (normalized == 'name' ||
          normalized == 'customer_name' ||
          normalized == 'company_name' ||
          normalized == 'prospect_name' ||
          normalized == 'contact_person' ||
          normalized == 'phone' ||
          normalized == 'contact_phone') {
        return false;
      }
      return true;
    }

    return false;
  }
}
