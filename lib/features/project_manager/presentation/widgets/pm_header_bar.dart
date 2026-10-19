import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/pm_mode_provider.dart';
import '../../providers/pm_company_provider.dart';
import '../../data/models/pm_company.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/sidebar_provider.dart';
import '../../../auth/providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _controller.addListener(() {
      if (mounted) setState(() {});
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
    super.dispose();
  }

  String _getTargetRoleDashboard() {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return AppRoutes.adminDashboard;
    if (profile.roles.contains(UserRole.admin)) return AppRoutes.adminDashboard;
    if (profile.roles.contains(UserRole.manager) ||
        profile.roles.contains(UserRole.salesHead) ||
        profile.roles.contains(UserRole.sales)) {
      return AppRoutes.salesDashboard;
    }
    return getRoleHome(profile.primaryRole);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(pmRecordModeProvider);
    final isPurchase = mode.isPurchase;
    final activeCompany = ref.watch(pmActiveCompanyProvider);
    final companies = ref.watch(pmCompaniesListProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isUltraWide = constraints.maxWidth >= 1250;
          final isMedium = constraints.maxWidth >= 720 && constraints.maxWidth < 1250;

          // 0a. Back Button for Mobile / Non-Wide Screens
          final backButton = Tooltip(
            message: 'Back to Dashboard',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final targetRoute = _getTargetRoleDashboard();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(targetRoute);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.arrowLeft,
                      size: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          );

          // 0b. Collapse/Expand Left Navigation Bar Button (Desktop/Tablet)
          final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);
          final collapseButton = Tooltip(
            message: isSidebarCollapsed ? 'Expand Navigation' : 'Collapse Navigation (Icons Only)',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ref.read(sidebarCollapsedProvider.notifier).state = !isSidebarCollapsed,
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: isSidebarCollapsed ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSidebarCollapsed ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isSidebarCollapsed ? LucideIcons.panelLeftOpen : LucideIcons.panelLeftClose,
                      size: 17,
                      color: isSidebarCollapsed ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          );

          // 1. Company Logo & Enterprise Selector
          final companyBlock = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern squircle enterprise logo
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF003899)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.building2,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Organization picker with refined status tag
              Flexible(
                child: PopupMenuButton<PmCompany>(
                  initialValue: activeCompany,
                  tooltip: 'Switch Organization',
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  onSelected: (comp) {
                    ref.read(pmActiveCompanyProvider.notifier).setCompany(comp);
                    _controller.clear();
                    widget.onSearchChanged('');
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem<PmCompany>(
                      enabled: false,
                      height: 30,
                      child: Text(
                        'SELECT ORGANIZATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    ...companies.map((comp) {
                      final isSelected = comp.id == activeCompany.id;
                      return PopupMenuItem<PmCompany>(
                        value: comp,
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: Icon(
                                  LucideIcons.building2,
                                  size: 14,
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                comp.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(LucideIcons.check, size: 16, color: Color(0xFF2563EB)),
                          ],
                        ),
                      );
                    }),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
                                  fontSize: 14.5,
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
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'PROJECT MANAGER',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );

          // 2. Pill Mode Switcher (SALES vs PURCHASE)
          final modeSwitcher = Container(
            height: 36,
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
                  onTap: () {
                    ref.read(pmRecordModeProvider.notifier).setMode(PmRecordMode.sales);
                    _controller.clear();
                    widget.onSearchChanged('');
                  },
                  borderRadius: BorderRadius.circular(9999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: !isPurchase ? const Color(0xFF2563EB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: !isPurchase
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.trendingUp,
                          size: 12.5,
                          color: !isPurchase ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'SALES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: !isPurchase ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Purchase Button
                InkWell(
                  onTap: () {
                    ref.read(pmRecordModeProvider.notifier).setMode(PmRecordMode.purchase);
                    _controller.clear();
                    widget.onSearchChanged('');
                  },
                  borderRadius: BorderRadius.circular(9999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isPurchase ? const Color(0xFF2563EB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: isPurchase
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.briefcase,
                          size: 12.5,
                          color: isPurchase ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'PURCHASE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
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

          // 3. Clean, modern, single-layer pill search bar
          final searchBar = Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              textAlignVertical: TextAlignVertical.center,
              onChanged: widget.onSearchChanged,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 42,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                          splashRadius: 16,
                          onPressed: () {
                            _controller.clear();
                            widget.onSearchChanged('');
                          },
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 42,
                ),
                hintText: 'Search ${activeCompany.name} (name, phone, site)...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          );

          // 4. Daily Transaction Entry Button
          Widget buildDailyTxButton({bool isMobile = false}) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/pm/daily-transactions'),
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 11 : 16),
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
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isMobile ? 'Daily Entry' : 'Daily Transaction Entry',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );

          // 5. Add Customer / Vendor Button
          Widget buildAddCustomerButton({bool isMobile = false}) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/pm/projects/new${isPurchase ? "?mode=purchase" : ""}'),
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 5,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.plus,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPurchase ? 'Add Vendor' : 'Add Customer',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );

          // 6. Settings gear button
          final settingsButton = Tooltip(
            message: 'App Settings & Company Management',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => const PmAppSettingsDialog(),
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
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
                const SizedBox(width: 10),
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

          // 3. Mobile Screens (< 720px): Clean enterprise 3-row header
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Back + Company Title & Selector + Settings
              Row(
                children: [
                  backButton,
                  const SizedBox(width: 10),
                  Expanded(child: companyBlock),
                  const SizedBox(width: 8),
                  settingsButton,
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: Search Bar
              searchBar,
              const SizedBox(height: 10),
              // Row 3: Command Control Strip (Mode Switcher + Action Button)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  modeSwitcher,
                  buildAddCustomerButton(isMobile: true),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
