// lib/features/quotation/providers/quotation_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

final pendingQuotationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('quotations')
      .select('*, sales_pipelines(*, customers(*), products(*))')
      .eq('status', 'pending_approval')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response as List);
});
