// lib/features/quotation_generator/data/qg_product_profiles_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/qg_product_profile.dart';

class QgProductProfilesRepository {
  final SupabaseClient _supabase;

  QgProductProfilesRepository(this._supabase);

  /// Fetches all active product profiles, ordered by label.
  Future<List<QgProductProfile>> getActiveProfiles() async {
    try {
      final res = await _supabase
          .from('qg_product_profiles')
          .select('*')
          .eq('is_active', true)
          .order('label');

      final list = (res as List)
          .map((row) => QgProductProfile.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();

      if (list.isEmpty) {
        return [QgProductProfile.defaultBoomBarrier()];
      }
      return list;
    } catch (e) {
      debugPrint('QgProductProfilesRepository.getActiveProfiles error: $e');
      return [QgProductProfile.defaultBoomBarrier()];
    }
  }

  /// Fetches a profile by its unique key.
  Future<QgProductProfile?> getProfileByKey(String key) async {
    try {
      final res = await _supabase
          .from('qg_product_profiles')
          .select('*')
          .eq('key', key)
          .maybeSingle();

      if (res != null) {
        return QgProductProfile.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('QgProductProfilesRepository.getProfileByKey error: $e');
    }
    if (key == 'boom_barrier') return QgProductProfile.defaultBoomBarrier();
    return null;
  }
}
