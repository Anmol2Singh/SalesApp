import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salesapp/features/customer_app/data/repositories/app_repositories.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';

// Repositories Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return SupabaseCustomerRepository();
});

// State & Auth Providers
final authStateProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return {};
  return ref.watch(authRepositoryProvider).getUserProfile();
});

// Product and Data Lists Providers
final productsProvider = FutureProvider<List<Product>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(customerRepositoryProvider).getProducts();
});

final advertisementProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(customerRepositoryProvider).getAdvertisementProducts();
});

final productDetailProvider = FutureProvider.family<Product?, String>((ref, productId) async {
  try {
    final purchased = await ref.watch(customerRepositoryProvider).getProducts();
    for (final p in purchased) {
      if (p.productId == productId) return p;
    }
  } catch (_) {}
  try {
    final ads = await ref.watch(customerRepositoryProvider).getAdvertisementProducts();
    for (final p in ads) {
      if (p.productId == productId) return p;
    }
  } catch (_) {}
  return null;
});

final serviceRequestsProvider = FutureProvider<List<ServiceRequest>>((ref) {
  return ref.watch(customerRepositoryProvider).getServiceRequests();
});

final invoicesProvider = FutureProvider<List<Invoice>>((ref) {
  return ref.watch(customerRepositoryProvider).getInvoices();
});

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  return ref.watch(customerRepositoryProvider).getSupportTickets();
});

// Dynamic Active Technician Provider
final activeTechnicianLocationProvider = StreamProvider.family<Technician, String>((ref, techId) {
  return ref.watch(customerRepositoryProvider).listenToTechnicianLocation(techId);
});

final activityLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(customerRepositoryProvider).getActivityLogs();
});

final notificationsViewedProvider = StateProvider<bool>((ref) {
  return false;
});

