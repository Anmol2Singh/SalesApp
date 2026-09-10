// lib/features/crm/screens/crm_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../providers/crm_providers.dart';

class CrmDashboardScreen extends ConsumerWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prospectsAsync = ref.watch(prospectsProvider);
    final leadsAsync = ref.watch(leadsProvider);

    final profile = ref.watch(currentProfileProvider);
    final isCrmStaff = profile?.primaryRole == UserRole.crmStaff;
    final isSalesOrAdmin = profile?.primaryRole.isSalesOrAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CRM Dashboard'),
        leading: isCrmStaff
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(prospectsProvider.notifier).load(refresh: true);
          if (isSalesOrAdmin) {
            ref.read(leadsProvider.notifier).load(refresh: true);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    if (!isSalesOrAdmin) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'All Prospects',
                              count: prospectsAsync.value?.length.toString() ?? '...',
                              icon: Icons.person_search,
                              color: Colors.blue,
                              onTap: () => context.go('/crm/prospects'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Added by Me',
                              count: prospectsAsync.value?.where((p) => p.createdBy == profile?.id).length.toString() ?? '...',
                              icon: Icons.person_add_alt_1,
                              color: const Color(0xFF6366F1),
                              onTap: () => context.go('/crm/prospects'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Recent Prospects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Prospects',
                              count: prospectsAsync.value?.where((p) => p.convertedToLeadId == null).length.toString() ?? '...',
                              icon: Icons.person_search,
                              color: Colors.blue,
                              onTap: () => context.go('/crm/prospects'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Open Leads',
                              count: leadsAsync.value?.where((l) => l.status != 'Won' && l.status != 'Lost').length.toString() ?? '...',
                              icon: Icons.trending_up,
                              color: Colors.orange,
                              onTap: () => context.go('/crm/leads'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Converted',
                              count: leadsAsync.value?.where((l) => l.convertedToCustomerId != null || l.status == 'Won').length.toString() ?? '...',
                              icon: Icons.star,
                              color: AppColors.success,
                              onTap: () => context.go('/crm/customers'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Leads Needing Follow-up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            if (!isSalesOrAdmin)
              prospectsAsync.when(
                data: (prospects) {
                  final recent = prospects.take(5).toList();
                  if (recent.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('No prospects logged yet. Click below to add one.', style: TextStyle(color: AppColors.textSecondary))),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final p = recent[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Card(
                            elevation: 0,
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                            ),
                            child: ListTile(
                              onTap: () => context.push('/crm/prospects/${p.id}'),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                              ),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              subtitle: Text('${p.phone} • ${p.source}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      },
                      childCount: recent.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
              )
            else
              leadsAsync.when(
                data: (leads) {
                  final activeLeads = leads.where((l) => l.status != 'Won' && l.status != 'Lost').toList();

                  activeLeads.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Oldest first

                  final followUpLeads = activeLeads.take(5).toList();

                  if (followUpLeads.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('All caught up! No pending follow-ups.', style: TextStyle(color: AppColors.textSecondary))),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final lead = followUpLeads[index];
                        final prospect = prospectsAsync.value?.where((p) => p.id == lead.prospectId).firstOrNull;
                        final displayName = (lead.prospectName != null && lead.prospectName!.isNotEmpty)
                            ? lead.prospectName!
                            : (prospect?.name ?? 'Lead #${lead.id.substring(0, 6)}');

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Card(
                            elevation: 0,
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                            ),
                            child: ListTile(
                              onTap: () => context.push('/crm/leads/${lead.id}'),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 20),
                              ),
                              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              subtitle: Text('${lead.productName} • ${lead.status}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      },
                      childCount: followUpLeads.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 16),
            Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
