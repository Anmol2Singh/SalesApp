import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_mode_provider.dart';
import '../../providers/pm_company_provider.dart';
import '../../data/models/pm_company.dart';

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
        color: Colors.white,
        border: Border(bottom: BorderSide(color: pm.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1050;

          // 1. Company Logo & Title Block
          final companyBlock = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue circle company icon
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF005CE6),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.building2,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + Subtitle
              PopupMenuButton<PmCompany>(
                initialValue: activeCompany,
                tooltip: 'Switch Company',
                onSelected: (comp) {
                  ref.read(pmActiveCompanyProvider.notifier).setCompany(comp);
                },
                itemBuilder: (ctx) => companies.map((comp) {
                  return PopupMenuItem<PmCompany>(
                    value: comp,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.building2, size: 16, color: Color(0xFF005CE6)),
                        const SizedBox(width: 8),
                        Text(
                          comp.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeCompany.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'TRADING & SUPPLY PROJECT MANAGER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF005CE6),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          // 2. Pill Mode Switcher (SALES vs PURCHASE)
          final modeSwitcher = Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sales Button
                InkWell(
                  onTap: () => ref.read(pmRecordModeProvider.notifier).setMode(PmRecordMode.sales),
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: !isPurchase ? const Color(0xFF005CE6) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: !isPurchase
                          ? [
                              BoxShadow(
                                color: const Color(0xFF005CE6).withOpacity(0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.trendingUp,
                          size: 13,
                          color: !isPurchase ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SALES',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: !isPurchase ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Purchase Button
                InkWell(
                  onTap: () => ref.read(pmRecordModeProvider.notifier).setMode(PmRecordMode.purchase),
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPurchase ? const Color(0xFF005CE6) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: isPurchase
                          ? [
                              BoxShadow(
                                color: const Color(0xFF005CE6).withOpacity(0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.briefcase,
                          size: 13,
                          color: isPurchase ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PURCHASE',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isPurchase ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          // 3. Search Bar Pill
          final searchBar = Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.search,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: searchQuery)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: searchQuery.length),
                      ),
                    onChanged: onSearchChanged,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search ${activeCompany.name} (name, phone, ...)',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => onSearchChanged(''),
                    child: const Icon(LucideIcons.x, size: 14, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          );

          // 4. Daily Transaction Entry Button
          final dailyTxButton = InkWell(
            onTap: () => context.push('/pm/daily-transactions'),
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.receiptText,
                    size: 15,
                    color: Color(0xFF005CE6),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Daily Transaction Entry',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF005CE6),
                    ),
                  ),
                ],
              ),
            ),
          );

          // 5. Add Customer / Vendor Button
          final addCustomerButton = InkWell(
            onTap: () => context.push('/pm/projects/new${isPurchase ? "?mode=purchase" : ""}'),
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF005CE6),
                borderRadius: BorderRadius.circular(9999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF005CE6).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.plus,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPurchase ? 'Add Vendor' : 'Add Customer',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );

          // 6. Settings gear button
          final settingsButton = InkWell(
            onTap: () => context.push('/pm/filter'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.settings,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                companyBlock,
                const SizedBox(width: 16),
                modeSwitcher,
                const SizedBox(width: 16),
                Expanded(child: searchBar),
                const SizedBox(width: 16),
                dailyTxButton,
                const SizedBox(width: 12),
                addCustomerButton,
                const SizedBox(width: 10),
                settingsButton,
              ],
            );
          }

          // Responsive Wrap layout for smaller screen widths
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              companyBlock,
              modeSwitcher,
              SizedBox(
                width: constraints.maxWidth > 550 ? 300 : constraints.maxWidth,
                child: searchBar,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dailyTxButton,
                  const SizedBox(width: 8),
                  addCustomerButton,
                  const SizedBox(width: 8),
                  settingsButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
