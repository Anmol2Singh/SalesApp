// lib/core/widgets/global_search_delegate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../router/app_router.dart';
import '../providers/supabase_provider.dart';

class GlobalSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  GlobalSearchDelegate(this.ref);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.trim().length < 2) {
      return const Center(
        child: Text(
          'Type at least 2 characters to search...',
          style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        ),
      );
    }

    final supabase = ref.read(supabaseClientProvider);

    return FutureBuilder<Map<String, List<dynamic>>>(
      future: _performSearch(supabase, query.trim()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final customers = snapshot.data?['customers'] ?? [];
        final deals = snapshot.data?['deals'] ?? [];

        if (customers.isEmpty && deals.isEmpty) {
          return const Center(
            child: Text(
              'No matches found.',
              style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (customers.isNotEmpty) ...[
              const Text(
                'Customers',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              ...customers.map((c) => ListTile(
                    leading: const Icon(Icons.business, color: AppColors.primary),
                    title: Text(c['customer_name'] ?? c['company_name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    subtitle: Text(c['contact_person'] ?? '', style: const TextStyle(fontFamily: 'Inter')),
                    onTap: () {
                      close(context, null);
                      context.push(AppRoutes.customerDetail.replaceAll(':id', c['id']));
                    },
                  )),
              const SizedBox(height: 24),
            ],
            if (deals.isNotEmpty) ...[
              const Text(
                'Deals / Pipelines',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              ...deals.map((d) => ListTile(
                    leading: const Icon(Icons.alt_route, color: AppColors.accent),
                    title: Text(d['customers']?['customer_name'] ?? d['customers']?['company_name'] ?? 'Unknown Customer', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    subtitle: Text('Product: ${d['products']?['name'] ?? ''} | Step: ${d['current_step']}', style: const TextStyle(fontFamily: 'Inter')),
                    onTap: () {
                      close(context, null);
                      context.push(AppRoutes.pipelineDetail.replaceAll(':id', d['id']));
                    },
                  )),
            ],
          ],
        );
      },
    );
  }

  Future<Map<String, List<dynamic>>> _performSearch(dynamic supabase, String term) async {
    try {
      final customerQuery = supabase
          .from('customers')
          .select('id, customer_name, contact_person')
          .ilike('customer_name', '%$term%')
          .isFilter('deleted_at', null)
          .limit(5);

      final dealQuery = supabase
          .from('sales_pipelines')
          .select('id, current_step, status, customers(customer_name), products(name)')
          .or('status.ilike.%$term%,current_step.ilike.%$term%')
          .isFilter('deleted_at', null)
          .limit(5);

      final results = await Future.wait<dynamic>([customerQuery, dealQuery]);
      return {
        'customers': results[0] as List<dynamic>,
        'deals': results[1] as List<dynamic>,
      };
    } catch (_) {
      return {'customers': [], 'deals': []};
    }
  }
}
