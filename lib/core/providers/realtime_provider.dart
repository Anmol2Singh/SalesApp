// lib/core/providers/realtime_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_provider.dart';

// Admin & Dashboard
import '../../features/dashboard/screens/admin_dashboard_screen.dart';
import '../../features/dashboard/providers/product_inquiries_provider.dart';
import '../../features/reports/screens/user_activity_report_screen.dart';
import '../../features/admin/screens/user_management_screen.dart';
import '../../features/admin/screens/product_catalog_screen.dart' as admin_catalog;
import '../../features/admin/providers/inventory_provider.dart';
import '../../features/admin/providers/manage_boq_items_provider.dart';

// Sales & Customers & AMC
import '../../features/pipelines/providers/pipelines_provider.dart';
import '../../features/customers/providers/customers_provider.dart';
import '../../features/amc/providers/amc_provider.dart';
import '../../features/quotation/screens/quotation_approval_screen.dart';
import '../../features/factory_order/screens/factory_queue_screen.dart';
import '../../features/purchase_order/screens/purchase_queue_screen.dart';

// CRM
import '../../features/crm/providers/crm_providers.dart';

// Complaints & Service
import '../../features/complaints/providers/complaints_provider.dart' hide customerPurchasedProductsProvider;
import '../../features/complaints/providers/part_orders_provider.dart';
import '../../features/complaints/providers/complaints_leaderboard_provider.dart';

// Customer App
import '../../features/customer_app/data/providers/app_providers.dart' as cust_providers;
import '../../features/customer_app/screens/customer_dashboard_screen.dart';
import '../../features/customer_app/features/dashboard/screens/main_dashboard.dart';

// Notifications & Auth
import '../../features/notifications/providers/notifications_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

/// App-wide real-time subscription provider.
/// Subscribes to PostgreSQL Change Events (INSERT, UPDATE, DELETE) across all
/// tables in the database, invalidating and updating UI providers dynamically.
final realtimeSubscriptionProvider = Provider<void>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final List<RealtimeChannel> channels = [];

  // ==========================================
  // 1. SALES & COMMERCIAL CHANNEL
  // Tables: sales_pipelines, customers, amc_contracts, quotations, sales_orders
  // ==========================================
  final salesChannel = supabase
      .channel('public:sales_channel')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sales_pipelines',
        callback: (payload) {
          debugPrint('⚡ Realtime: sales_pipelines event: ${payload.eventType}');
          // Refresh deal lists and admin stats
          ref.read(pipelinesNotifierProvider.notifier).refresh();
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(activityReportProvider);
          ref.invalidate(customerPurchasedProductsProvider);
          ref.invalidate(cust_providers.productsProvider);
          ref.invalidate(cust_providers.advertisementProductsProvider);
          ref.invalidate(admin_catalog.productDealCountsProvider);

          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          final pipelineId = newRecord['id'] ?? oldRecord['id'];
          if (pipelineId != null) {
            ref.invalidate(pipelineDetailProvider(pipelineId.toString()));
            ref.invalidate(workflowStepsProvider(pipelineId.toString()));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'customers',
        callback: (payload) {
          debugPrint('⚡ Realtime: customers event: ${payload.eventType}');
          ref.read(customersNotifierProvider.notifier).refresh();
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(activityReportProvider);
          ref.invalidate(customerPurchasedProductsProvider);
          ref.invalidate(cust_providers.userProfileProvider);

          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          final customerId = newRecord['id'] ?? oldRecord['id'];
          if (customerId != null) {
            ref.invalidate(customerDetailProvider(customerId.toString()));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'amc_contracts',
        callback: (payload) {
          debugPrint('⚡ Realtime: amc_contracts event: ${payload.eventType}');
          ref.read(amcNotifierProvider.notifier).refresh();
          ref.invalidate(amcExpiringSoonCountProvider);
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(customerPurchasedProductsProvider);
          ref.invalidate(cust_providers.serviceRequestsProvider);

          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;

          final amcId = newRecord['id'] ?? oldRecord['id'];
          if (amcId != null) {
            ref.invalidate(amcDetailProvider(amcId.toString()));
          }

          final customerId = newRecord['customer_id'] ?? oldRecord['customer_id'];
          if (customerId != null) {
            ref.invalidate(amcForCustomerProvider(customerId.toString()));
            ref.invalidate(customerDetailProvider(customerId.toString()));
          }

          final productId = newRecord['product_id'] ?? oldRecord['product_id'];
          if (customerId != null && productId != null) {
            ref.invalidate(amcForCustomerProductProvider((
              customerId: customerId.toString(),
              productId: productId.toString(),
            )));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'quotations',
        callback: (payload) {
          debugPrint('⚡ Realtime: quotations event: ${payload.eventType}');
          ref.invalidate(pendingQuotationsProvider);
          ref.invalidate(cust_providers.invoicesProvider);
          ref.invalidate(dashboardStatsProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sales_orders',
        callback: (payload) {
          debugPrint('⚡ Realtime: sales_orders event: ${payload.eventType}');
          ref.invalidate(cust_providers.invoicesProvider);
          ref.invalidate(customerPurchasedProductsProvider);
          ref.invalidate(dashboardStatsProvider);
        },
      )
      .subscribe();
  channels.add(salesChannel);

  // ==========================================
  // 2. CRM CHANNEL
  // Tables: crm_prospects, crm_leads, crm_communications
  // ==========================================
  final crmChannel = supabase
      .channel('public:crm_channel')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'crm_prospects',
        callback: (payload) {
          debugPrint('⚡ Realtime: crm_prospects event: ${payload.eventType}');
          ref.read(prospectsProvider.notifier).load();
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(activityReportProvider);

          final id = payload.newRecord['id'] ?? payload.oldRecord['id'];
          if (id != null) {
            ref.invalidate(prospectByIdProvider(id.toString()));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'crm_leads',
        callback: (payload) {
          debugPrint('⚡ Realtime: crm_leads event: ${payload.eventType}');
          ref.read(leadsProvider.notifier).load();
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(activityReportProvider);
          ref.invalidate(productInquiriesProvider);

          final id = payload.newRecord['id'] ?? payload.oldRecord['id'];
          if (id != null) {
            ref.invalidate(leadByIdProvider(id.toString()));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'crm_communications',
        callback: (payload) {
          debugPrint('⚡ Realtime: crm_communications event: ${payload.eventType}');
          ref.invalidate(activityReportProvider);
          final leadId = payload.newRecord['lead_id'] ?? payload.oldRecord['lead_id'];
          if (leadId != null) {
            ref.invalidate(leadCommunicationsProvider(leadId.toString()));
          }
        },
      )
      .subscribe();
  channels.add(crmChannel);

  // ==========================================
  // 3. SERVICE & COMPLAINTS CHANNEL
  // Tables: complaints, complaint_part_orders, technicians, bookings, support_tickets
  // ==========================================
  final serviceChannel = supabase
      .channel('public:service_channel')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'complaints',
        callback: (payload) {
          debugPrint('⚡ Realtime: complaints event: ${payload.eventType}');
          ref.read(complaintsProvider.notifier).load(refresh: true);
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(activityReportProvider);
          ref.invalidate(cust_providers.serviceRequestsProvider);
          ref.invalidate(customerActivityProvider);
          ref.invalidate(complaintsLeaderboardProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'complaint_part_orders',
        callback: (payload) {
          debugPrint('⚡ Realtime: complaint_part_orders event: ${payload.eventType}');
          final complaintId = payload.newRecord['complaint_id'] ?? payload.oldRecord['complaint_id'];
          if (complaintId != null) {
            ref.invalidate(partOrdersForComplaintProvider(complaintId.toString()));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'technicians',
        callback: (payload) {
          debugPrint('⚡ Realtime: technicians event: ${payload.eventType}');
          ref.invalidate(availableTechniciansProvider);
          ref.invalidate(allUsersProvider);
          ref.invalidate(complaintsLeaderboardProvider);
          ref.invalidate(usersListProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bookings',
        callback: (payload) {
          debugPrint('⚡ Realtime: bookings event: ${payload.eventType}');
          ref.invalidate(cust_providers.serviceRequestsProvider);
          ref.invalidate(customerActivityProvider);
        },
      )
      .subscribe();
  channels.add(serviceChannel);

  // ==========================================
  // 4. OPERATIONS, ORDERS & PRODUCTS CHANNEL
  // Tables: factory_orders, purchase_orders, products, inventory_items, boq_items
  // ==========================================
  final operationsChannel = supabase
      .channel('public:operations_channel')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'factory_orders',
        callback: (payload) {
          debugPrint('⚡ Realtime: factory_orders event: ${payload.eventType}');
          ref.invalidate(factoryQueueProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'purchase_orders',
        callback: (payload) {
          debugPrint('⚡ Realtime: purchase_orders event: ${payload.eventType}');
          ref.invalidate(purchaseQueueProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'products',
        callback: (payload) {
          debugPrint('⚡ Realtime: products event: ${payload.eventType}');
          ref.invalidate(productsListProvider);
          ref.invalidate(cust_providers.productsProvider);
          ref.invalidate(cust_providers.advertisementProductsProvider);
          ref.invalidate(admin_catalog.productsProvider);
          ref.invalidate(admin_catalog.productDealCountsProvider);
          ref.invalidate(productLaunchesProvider);

          final productId = payload.newRecord['id'] ?? payload.oldRecord['id'];
          if (productId != null) {
            ref.invalidate(cust_providers.productDetailProvider(productId.toString()));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'inventory_items',
        callback: (payload) {
          debugPrint('⚡ Realtime: inventory_items event: ${payload.eventType}');
          ref.invalidate(inventoryProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'boq_items',
        callback: (payload) {
          debugPrint('⚡ Realtime: boq_items event: ${payload.eventType}');
          final productId = payload.newRecord['product_id'] ?? payload.oldRecord['product_id'];
          if (productId != null) {
            ref.invalidate(productBoqItemsProvider(productId.toString()));
          }
        },
      )
      .subscribe();
  channels.add(operationsChannel);

  // ==========================================
  // 5. SYSTEM, PROFILES & INQUIRIES CHANNEL
  // Tables: profiles, customer_profiles, product_inquiries, notifications, activity_logs
  // ==========================================
  final systemChannel = supabase
      .channel('public:system_channel')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        callback: (payload) {
          debugPrint('⚡ Realtime: profiles event: ${payload.eventType}');
          ref.invalidate(usersListProvider);
          ref.invalidate(allUsersProvider);
          ref.invalidate(cust_providers.userProfileProvider);
          ref.invalidate(currentProfileProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'customer_profiles',
        callback: (payload) {
          debugPrint('⚡ Realtime: customer_profiles event: ${payload.eventType}');
          ref.invalidate(cust_providers.userProfileProvider);
          ref.invalidate(currentProfileProvider);
          ref.invalidate(allUsersProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'product_inquiries',
        callback: (payload) {
          debugPrint('⚡ Realtime: product_inquiries event: ${payload.eventType}');
          ref.invalidate(productInquiriesProvider);
          ref.invalidate(dashboardStatsProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        callback: (payload) {
          debugPrint('⚡ Realtime: notifications event: ${payload.eventType}');
          ref.read(notificationsNotifierProvider.notifier).refresh();
          ref.invalidate(unreadNotificationCountProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'activity_logs',
        callback: (payload) {
          debugPrint('⚡ Realtime: activity_logs event: ${payload.eventType}');
          ref.invalidate(cust_providers.activityLogsProvider);
          ref.invalidate(customerActivityProvider);
        },
      )
      .subscribe();
  channels.add(systemChannel);

  // Clean disposal of all subscriptions when container is disposed
  ref.onDispose(() {
    for (final channel in channels) {
      channel.unsubscribe();
    }
  });
});
