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
      final res = await supabase
          .from('profiles')
          .select('id')
          .inFilter('role', roles);
          
      final List<Map<String, dynamic>> notifications = [];
      for (final user in res) {
        notifications.add({
          'user_id': user['id'],
          'title': title,
          'body': body,
          'type': type,
          if (relatedPipelineId != null) 'related_pipeline_id': relatedPipelineId,
          if (relatedAmcId != null) 'related_amc_id': relatedAmcId,
        });
      }
      
      if (notifications.isNotEmpty) {
        await supabase.from('notifications').insert(notifications);
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
