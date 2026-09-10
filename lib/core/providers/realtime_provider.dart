// lib/core/providers/realtime_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_provider.dart';
import '../../features/dashboard/screens/admin_dashboard_screen.dart';
import '../../features/pipelines/providers/pipelines_provider.dart';
import '../../features/customers/providers/customers_provider.dart';
import '../../features/amc/providers/amc_provider.dart';

final realtimeSubscriptionProvider = Provider.autoDispose<void>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  // Subscribe to changes on sales_pipelines
  final pipelineChannel = supabase
      .channel('public:sales_pipelines')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sales_pipelines',
        callback: (payload) {
          // Refresh lists and stats
          ref.read(pipelinesNotifierProvider.notifier).refresh();
          ref.invalidate(dashboardStatsProvider);
          
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          final pipelineId = newRecord['id'] ?? oldRecord['id'];
          if (pipelineId != null) {
            ref.invalidate(pipelineDetailProvider(pipelineId));
          }
        },
      )
      .subscribe();

  // Subscribe to changes on customers
  final customerChannel = supabase
      .channel('public:customers')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'customers',
        callback: (payload) {
          // Refresh customer lists
          ref.read(customersNotifierProvider.notifier).refresh();
          ref.invalidate(dashboardStatsProvider);
          
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          final customerId = newRecord['id'] ?? oldRecord['id'];
          if (customerId != null) {
            ref.invalidate(customerDetailProvider(customerId));
          }
        },
      )
      .subscribe();

  // Subscribe to changes on amc_contracts
  final amcChannel = supabase
      .channel('public:amc_contracts')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'amc_contracts',
        callback: (payload) {
          ref.read(amcNotifierProvider.notifier).refresh();
          ref.invalidate(amcExpiringSoonCountProvider);
          ref.invalidate(dashboardStatsProvider);
          
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          final amcId = newRecord['id'] ?? oldRecord['id'];
          if (amcId != null) {
            ref.invalidate(amcDetailProvider(amcId));
          }
          
          final customerId = newRecord['customer_id'] ?? oldRecord['customer_id'];
          if (customerId != null) {
            ref.invalidate(amcForCustomerProvider(customerId));
            ref.invalidate(customerDetailProvider(customerId));
          }
          
          final productId = newRecord['product_id'] ?? oldRecord['product_id'];
          if (customerId != null && productId != null) {
            ref.invalidate(amcForCustomerProductProvider((customerId: customerId, productId: productId)));
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    pipelineChannel.unsubscribe();
    customerChannel.unsubscribe();
    amcChannel.unsubscribe();
  });
});
