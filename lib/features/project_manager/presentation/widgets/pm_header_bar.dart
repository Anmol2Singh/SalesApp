import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_mode_provider.dart';
import '../../providers/pm_company_provider.dart';
import '../../data/models/pm_company.dart';
import '../../../../core/providers/sidebar_provider.dart';
import 'pm_app_settings_dialog.dart';

class PmHeaderBar extends ConsumerStatefulWidget {
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
  ConsumerState<PmHeaderBar> createState() => _PmHeaderBarState();
}

class _PmHeaderBarState extends ConsumerState<PmHeaderBar> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant PmHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isUltraWide = constraints.maxWidth >= 1250;
          final isMedium = constraints.maxWidth >= 720 && constraints.maxWidth < 1250;

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
              Flexible(
                child: PopupMenuButton<PmCompany>(
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
                          Flexible(
                            child: Text(
                              activeCompany.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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

          // 3. Search Bar Pill (Entire pill clickable & focused, crisp white, full text space)
          final searchBar = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusNode.requestFocus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: _isFocused ? const Color(0xFF005CE6) : const Color(0xFFCBD5E1),
                  width: _isFocused ? 1.5 : 1.0,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFF005CE6).withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search,
                    size: 16,
                    color: _isFocused ? const Color(0xFF005CE6) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: widget.onSearchChanged,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search ${activeCompany.name} (name, phone, site)...',
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
                  if (_controller.text.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _controller.clear();
                        widget.onSearchChanged('');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(LucideIcons.x, size: 14, color: Color(0xFF64748B)),
                      ),
                    ),
                ],
              ),
            ),
          );

          // 4. Daily Transaction Entry Button
          Widget buildDailyTxButton({bool isMobile = false}) => InkWell(
            onTap: () => context.push('/pm/daily-transactions'),
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.receiptText,
                    size: 15,
                    color: Color(0xFF005CE6),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isMobile ? 'Daily Entry' : 'Daily Transaction Entry',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF005CE6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );

          // 5. Add Customer / Vendor Button
          Widget buildAddCustomerButton({bool isMobile = false}) => InkWell(
            onTap: () => context.push('/pm/projects/new${isPurchase ? "?mode=purchase" : ""}'),
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18),
              alignment: Alignment.center,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.plus,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isPurchase ? 'Add Vendor' : 'Add Customer',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );

          // 0. Collapse/Expand Left Navigation Bar Button
          final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);
          final collapseButton = Tooltip(
            message: isSidebarCollapsed ? 'Expand Navigation' : 'Collapse Navigation (Icons Only)',
            child: InkWell(
              onTap: () => ref.read(sidebarCollapsedProvider.notifier).state = !isSidebarCollapsed,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: isSidebarCollapsed ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSidebarCollapsed ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Icon(
                    isSidebarCollapsed ? LucideIcons.panelLeftOpen : LucideIcons.panelLeftClose,
                    size: 17,
                    color: isSidebarCollapsed ? const Color(0xFF005CE6) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );

          // 6. Settings gear button
          final settingsButton = Tooltip(
            message: 'App Settings & Company Management',
            child: InkWell(
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => const PmAppSettingsDialog(),
              ),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 40,
                width: 40,
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
            ),
          );

          // 1. Desktop Ultra-Wide (>= 1250px): Single clean row with ample space
          if (isUltraWide) {
            return Row(
              children: [
                collapseButton,
                const SizedBox(width: 12),
                companyBlock,
                const SizedBox(width: 16),
                modeSwitcher,
                const SizedBox(width: 16),
                Expanded(child: searchBar),
                const SizedBox(width: 16),
                buildDailyTxButton(isMobile: false),
                const SizedBox(width: 12),
                buildAddCustomerButton(isMobile: false),
                const SizedBox(width: 10),
                settingsButton,
              ],
            );
          }

          // 2. Medium Screens (720px - 1249px): 2 clean rows so search bar is not squashed
          if (isMedium) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    collapseButton,
                    const SizedBox(width: 10),
                    companyBlock,
                    const Spacer(),
                    modeSwitcher,
                    const SizedBox(width: 10),
                    settingsButton,
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: searchBar),
                    const SizedBox(width: 12),
                    buildDailyTxButton(isMobile: false),
                    const SizedBox(width: 8),
                    buildAddCustomerButton(isMobile: false),
                  ],
                ),
              ],
            );
          }

          // 3. Mobile Screens (< 720px): Adaptive stacked layout with touch-friendly targets
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  collapseButton,
                  const SizedBox(width: 10),
                  Expanded(child: companyBlock),
                  settingsButton,
                ],
              ),
              const SizedBox(height: 10),
              Center(child: modeSwitcher),
              const SizedBox(height: 10),
              searchBar,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: buildDailyTxButton(isMobile: true)),
                  const SizedBox(width: 8),
                  Expanded(child: buildAddCustomerButton(isMobile: true)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
