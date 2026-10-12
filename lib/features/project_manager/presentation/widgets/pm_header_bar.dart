import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_mode_provider.dart';
import '../../providers/pm_company_provider.dart';
import '../../data/models/pm_company.dart';
import 'pm_button.dart';
import 'pm_search_input.dart';

class PmHeaderBar extends ConsumerWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onRefresh;

  const PmHeaderBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = context.pm;
    final mode = ref.watch(pmRecordModeProvider);
    final isPurchase = mode.isPurchase;
    final activeCompany = ref.watch(pmActiveCompanyProvider);
    final companies = ref.watch(pmCompaniesListProvider);

    return Container(
      decoration: BoxDecoration(
        color: pm.card.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: pm.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Company Selector & Mode Switcher
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Company Selector Dropdown
              PopupMenuButton<PmCompany>(
                initialValue: activeCompany,
                onSelected: (comp) {
                  ref.read(pmActiveCompanyProvider.notifier).setCompany(comp);
                },
                itemBuilder: (ctx) => companies.map((comp) {
                  return PopupMenuItem<PmCompany>(
                    value: comp,
                    child: Row(
                      children: [
                        Icon(LucideIcons.building2, size: 16, color: pm.primary),
                        const SizedBox(width: 8),
                        Text(comp.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pm.secondary,
                    borderRadius: BorderRadius.circular(pm.radiusMd),
                    border: Border.all(color: pm.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.building2, size: 16, color: pm.primary),
                      const SizedBox(width: 8),
                      Text(
                        activeCompany.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: pm.foreground,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(LucideIcons.chevronDown, size: 14, color: pm.mutedForeground),
                    ],
                  ),
                ),
              ),

              // Mode Switcher: "Sales" (Projects) vs "Purchase" (Vendors)
              Container(
                decoration: BoxDecoration(
                  color: pm.secondary,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: pm.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => ref.read(pmRecordModeProvider.notifier).setMode(PmRecordMode.sales),
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: !isPurchase ? pm.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          'Sales (Projects)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !isPurchase ? pm.primaryForeground : pm.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => ref.read(pmRecordModeProvider.notifier).setMode(PmRecordMode.purchase),
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPurchase ? pm.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          'Purchase (Vendors)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPurchase ? pm.primaryForeground : pm.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Search Bar & Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final searchWidget = PmSearchInput(
                value: searchQuery,
                onChanged: onSearchChanged,
                hintText: isPurchase
                    ? 'Search vendors by name, party, mobile, address...'
                    : 'Search projects by site, customer, ID, mobile, address...',
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PmButton(
                    variant: PmButtonVariant.outline,
                    size: PmButtonSize.sm,
                    onPressed: () => context.push('/pm/filter'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.slidersHorizontal, size: 14),
                        SizedBox(width: 6),
                        Text('Filter'),
                      ],
                    ),
                  ),
                  PmButton(
                    variant: PmButtonVariant.outline,
                    size: PmButtonSize.sm,
                    onPressed: () => context.push('/pm/daily-transactions'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.receiptText, size: 14),
                        SizedBox(width: 6),
                        Text('Day-Book'),
                      ],
                    ),
                  ),
                  PmButton(
                    variant: PmButtonVariant.defaultVariant,
                    size: PmButtonSize.sm,
                    onPressed: () => context.push('/pm/projects/new'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.plus, size: 14),
                        const SizedBox(width: 6),
                        Text(isPurchase ? 'Add Vendor' : 'Create Project'),
                      ],
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: searchWidget),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchWidget,
                  const SizedBox(height: 8),
                  actionButtons,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
