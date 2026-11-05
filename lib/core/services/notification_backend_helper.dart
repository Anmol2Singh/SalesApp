import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationBackendHelper {
  static Future<void> notifyRoles({
    required SupabaseClient supabase,
    required List<String> roles,
    required String title,
    required String body,
    required String type,
    String? relatedPipelineId,
    String? relatedAmcId,
  }) async {
    try {
      // Include service_head for installation, complaints, and boq targeted alerts
      final targetRoles = Set<String>.from(roles);
      if (targetRoles.contains('installation') ||
          targetRoles.contains('complaints') ||
          targetRoles.contains('boq')) {
        targetRoles.add('service_head');
      }

      final res = await supabase
          .from('profiles')
          .select('id, role, roles')
          .eq('is_active', true);

      final Set<String> recipientIds = {};
      for (final user in res) {
        final id = user['id']?.toString();
        if (id == null || id.isEmpty) continue;

        final userRole = user['role']?.toString();
        final userRolesList = (user['roles'] is List)
            ? (user['roles'] as List).map((e) => e.toString()).toList()
            : <String>[];

        final matchesRole =
            (userRole != null && targetRoles.contains(userRole)) ||
                userRolesList.any((r) => targetRoles.contains(r));

        if (matchesRole) {
          recipientIds.add(id);
        }
      }

      for (final uid in recipientIds) {
        await notifyUser(
          supabase: supabase,
          userId: uid,
          title: title,
          body: body,
          type: type,
          relatedPipelineId: relatedPipelineId,
          relatedAmcId: relatedAmcId,
        );
      }
    } catch (e) {
      debugPrint('Error notifying roles: $e');
    }
  }

  static Future<void> notifyUser({
    required SupabaseClient supabase,
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedPipelineId,
    String? relatedAmcId,
  }) async {
    try {
      // Prevent repeated notifications for same user
      var check = supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('title', title);

      if (relatedPipelineId != null) {
        check = check.eq('related_pipeline_id', relatedPipelineId);
      } else {
        check = check.eq('body', body);
      }

      final existing = await check.limit(1);
      if (existing is List && existing.isNotEmpty) {
        debugPrint('Skipping duplicate notification for user $userId: $title');
        return;
      }

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        if (relatedPipelineId != null) 'related_pipeline_id': relatedPipelineId,
        if (relatedAmcId != null) 'related_amc_id': relatedAmcId,
      });
    } catch (e) {
      debugPrint('Error notifying user: $e');
    }
  }
}
