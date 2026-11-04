// lib/features/reports/screens/customer_report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/customer_report_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/widgets/export_preview_dialog.dart';
import '../../daily_tasks/widgets/task_form_dialog.dart';

final allCustomersForReportProvider = FutureProvider<List<Customer>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);

  if (profile == null) return [];

  final isAdmin = profile.primaryRole == UserRole.admin || profile.roles.contains(UserRole.admin);
  final isSalesHead = profile.primaryRole == UserRole.salesHead || profile.roles.contains(UserRole.salesHead);
  final isManager = profile.primaryRole == UserRole.manager || profile.roles.contains(UserRole.manager);
  final isSales = profile.primaryRole == UserRole.sales || profile.roles.contains(UserRole.sales);

  if (!isAdmin && !isSalesHead && !isManager && !isSales) {
    return [];
  }

  final canViewAll = isAdmin || isSalesHead || isManager || profile.primaryRole.canViewAllCustomers;

  var query = supabase
      .from('customers')
      .select('*')
      .isFilter('deleted_at', null);

  if (!canViewAll) {
    query = query.or('created_by.eq.${profile.id},assigned_to.eq.${profile.id}');
  }

  final response = await query.order('customer_name', ascending: true);

  return (response as List).map((c) => Customer.fromJson(c)).toList();
});

final customer360DataProvider = FutureProvider.family<Customer360Data?, Customer?>((ref, customer) async {
  if (customer == null) return null;
  final supabase = ref.watch(supabaseClientProvider);
  return CustomerReportService.fetchCustomerData(supabase, customer);
});

class CustomerReportScreen extends ConsumerStatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  ConsumerState<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends ConsumerState<CustomerReportScreen> {
  Customer? _selectedCustomer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGenerating = false;
  int _selectedViewTab = 0; // 0: 360 Overview & Progress, 1: Timeline Feed

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) return;
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) return;
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final fullNumber = clean.length == 10 ? '91$clean' : clean;
    final uri = Uri.parse('https://wa.me/$fullNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openQuickTaskModal(Customer customer) async {
    final result = await TaskFormDialog.show(
      context,
      preselectedCustomerId: customer.id,
      preselectedCustomerName: customer.companyName,
    );
    if (result == true && mounted) {
      ref.invalidate(customer360DataProvider(_selectedCustomer));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily task logged and 360 Report updated!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersForReportProvider);
    final dataAsync = ref.watch(customer360DataProvider(_selectedCustomer));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer 360 Report'),
        backgroundColor: AppColors.navBarColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_selectedCustomer != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Report Data',
              onPressed: () => ref.invalidate(customer360DataProvider(_selectedCustomer)),
            ),
        ],
      ),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No customers found or permission denied.'));
          }

          final q = _searchQuery.trim().toLowerCase();
          final filteredCustomers = q.isEmpty
              ? customers
              : customers.where((c) {
                  final name = c.customerName.toLowerCase();
                  final comp = c.companyName.toLowerCase();
                  final contact = (c.contactPerson ?? '').toLowerCase();
                  final phone = (c.phone ?? '').toLowerCase();
                  return name.contains(q) || comp.contains(q) || contact.contains(q) || phone.contains(q);
                }).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedCustomer == null) ...[
                  const Text(
                    'Search & Select Customer',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // Search Box
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search customer by name, company, or phone...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  // Filtered Customer List
                  Expanded(
                    child: filteredCustomers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_search, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No customers matching "$_searchQuery"',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).size.width >= 800
                                  ? 8.0
                                  : (MediaQuery.of(context).padding.bottom > 20
                                      ? MediaQuery.of(context).padding.bottom
                                      : 88.0),
                            ),
                            itemCount: filteredCustomers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final c = filteredCustomers[index];
                              final title = c.customerName.trim().isNotEmpty
                                  ? c.customerName
                                  : (c.contactPerson?.isNotEmpty == true ? c.contactPerson! : c.companyName);
                              final subtitle = [
                                if (c.companyName.isNotEmpty && c.companyName != title) c.companyName,
                                if (c.phone != null && c.phone!.isNotEmpty) c.phone,
                              ].join(' • ');

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      title.isNotEmpty ? title[0].toUpperCase() : 'C',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: subtitle.isNotEmpty
                                      ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                                      : null,
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
                                  onTap: () {
                                    setState(() {
                                      _selectedCustomer = c;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ] else ...[
                  // Selected Customer Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            _selectedCustomer!.customerName.isNotEmpty
                                ? _selectedCustomer!.customerName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCustomer!.customerName,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_selectedCustomer!.phone != null && _selectedCustomer!.phone!.isNotEmpty)
                                Text(
                                  '📞 ${_selectedCustomer!.phone}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedCustomer = null;
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: const Text('Change', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 32),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Segmented Tabs: Overview / Feed
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedViewTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedViewTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: _selectedViewTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '360 Overview & Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedViewTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedViewTab == 0 ? AppColors.primary : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedViewTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedViewTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: _selectedViewTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Interaction Timeline Feed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedViewTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedViewTab == 1 ? AppColors.primary : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: dataAsync.when(
                      data: (data) {
                        if (data == null) return const SizedBox.shrink();
                        return _buildReportDetails(data);
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildReportDetails(Customer360Data data) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final bottomPad = isWide
        ? 8.0
        : (MediaQuery.of(context).padding.bottom > 20
            ? MediaQuery.of(context).padding.bottom
            : 88.0);

    return Column(
      children: [
        Expanded(
          child: _selectedViewTab == 0
              ? _buildOverviewTab(data)
              : _buildTimelineFeedTab(data),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: bottomPad),
          child: _buildActionButtons(data),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Customer360Data data) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        // 1. Customer Info Card with Quick Communication Bar
        _buildCustomerInfoCard(),
        const SizedBox(height: 14),

        // 2. High-Level Key Financial & Activity Highlights
        _buildFinancialHighlightRow(data),
        const SizedBox(height: 14),

        // 3. Stats Row
        _buildStatsRow(data),
        const SizedBox(height: 20),

        // 4. CUSTOMER DEAL PROGRESS (Item 4)
        _buildCustomerDealProgressSection(data),
        const SizedBox(height: 20),

        // 5. STAFF INCLUDED & "WHO DID WHAT" (Item 3)
        _buildStaffInvolvedSection(data),
        const SizedBox(height: 20),

        // 6. Tasks
        _buildSectionTitle('Daily Tasks Recorded (${data.tasks.length})', Icons.assignment_turned_in_outlined),
        if (data.tasks.isEmpty)
          const Text('No daily tasks recorded for this customer.', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          ...data.tasks.map((t) => _buildDataCard(
                t['task_description'] ?? 'Task',
                'By: ${t['user_name'] ?? 'Staff'}',
                t['completed_at'] ?? t['created_at'],
                Icons.check_circle_outline,
                Colors.teal,
              )),
        const SizedBox(height: 18),

        // 7. Installation Reports
        _buildSectionTitle('Installation Reports (${data.installations.length})', Icons.precision_manufacturing_outlined),
        if (data.installations.isEmpty)
          const Text('No installation records found for this customer.', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          ...data.installations.map((inst) => _buildInstallationCard(inst)),
        const SizedBox(height: 18),

        // 7. Service Visits
        _buildSectionTitle('Service Visits (${data.serviceVisits.length})', Icons.handyman_outlined),
        if (data.serviceVisits.isEmpty)
          const Text('No service visits recorded.', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          ...data.serviceVisits.map((s) => _buildDataCard(
                s['notes'] ?? s['technician_name'] ?? 'Visit',
                'Tech: ${s['technician_name'] ?? '-'} • Status: ${s['status'] ?? '-'}',
                s['scheduled_date'] ?? s['created_at'],
                Icons.build_circle_outlined,
                Colors.orange,
              )),
        const SizedBox(height: 18),

        // 8. Complaints
        _buildSectionTitle('Customer Complaints (${data.complaints.length})', Icons.report_problem_outlined),
        if (data.complaints.isEmpty)
          const Text('No complaints logged. Excellent client satisfaction!', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          ...data.complaints.map((c) => _buildDataCard(
                'Ticket #${c['ticket_number'] ?? _shortId(c['id'])}: ${c['complaint_type'] ?? 'Issue'}',
                'Status: ${c['status'] ?? '-'} • Priority: ${c['priority'] ?? '-'}',
                c['created_at'],
                Icons.warning_amber_rounded,
                Colors.red,
              )),
        const SizedBox(height: 18),
      ],
    );
  }

  // -------------------------------------------------------------
  // CUSTOMER INFO & QUICK ACTION BAR
  // -------------------------------------------------------------
  Widget _buildCustomerInfoCard() {
    final c = _selectedCustomer!;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.companyName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (c.gstNumber != null && c.gstNumber!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Text(
                      'GST: ${c.gstNumber}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.indigo.shade800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (c.contactPerson != null && c.contactPerson!.isNotEmpty)
              _buildMetaRow(Icons.person_outline, 'Contact Person', c.contactPerson!),
            if (c.phone != null && c.phone!.isNotEmpty)
              _buildMetaRow(Icons.phone_outlined, 'Phone', c.phone!),
            if (c.email != null && c.email!.isNotEmpty)
              _buildMetaRow(Icons.mail_outline, 'Email', c.email!),
            if (c.address != null && c.address!.isNotEmpty)
              _buildMetaRow(Icons.location_on_outlined, 'Address', c.address!),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),

            // Quick Actions: Call, WhatsApp, Log Task
            Row(
              children: [
                if (c.phone != null && c.phone!.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(c.phone),
                      icon: const Icon(Icons.call, size: 14, color: AppColors.primary),
                      label: const Text('Call', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(c.phone),
                      icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF25D366)),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12, color: Color(0xFF1E7E34))),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E7E34),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openQuickTaskModal(c),
                    icon: const Icon(Icons.add_task, size: 14, color: Colors.white),
                    label: const Text('+ Log Task', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // FINANCIAL & STATS CARDS
  // -------------------------------------------------------------
  Widget _buildFinancialHighlightRow(Customer360Data data) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    final totalQuoted = currencyFmt.format(data.totalQuotedValue);
    final totalApproved = currencyFmt.format(data.totalApprovedValue);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Quoted Value', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  totalQuoted,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Approved: $totalApproved',
                  style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Staff Members Involved', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  '${data.uniqueStaffCount} Staff',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${data.tasks.length} tasks • ${data.serviceVisits.length} visits',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Customer360Data data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatItem('Pipelines', data.pipelines.length.toString(), Colors.blue),
          const SizedBox(width: 8),
          _buildStatItem('Tasks', data.tasks.length.toString(), Colors.green),
          const SizedBox(width: 8),
          _buildStatItem('Installs', data.installations.length.toString(), Colors.cyan.shade700),
          const SizedBox(width: 8),
          _buildStatItem('Visits', data.serviceVisits.length.toString(), Colors.orange),
          const SizedBox(width: 8),
          _buildStatItem('Complaints', data.complaints.length.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CUSTOMER DEAL PROGRESS (Item 4)
  // -------------------------------------------------------------
  Widget _buildCustomerDealProgressSection(Customer360Data data) {
    final dealList = data.dealProgressList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Customer Deal Progress (${dealList.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Live stage tracking for all active & completed deals for this customer.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),

        if (dealList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.grey),
                SizedBox(width: 10),
                Text('No sales pipelines or deals found for this customer.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
        else
          ...dealList.map((deal) => _buildDealProgressCard(deal)),
      ],
    );
  }

  Widget _buildDealProgressCard(DealProgressInfo deal) {
    final percent = deal.progressPercent;
    final color = percent >= 100
        ? AppColors.success
        : (percent >= 60 ? Colors.indigo : AppColors.primary);

    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    deal.productName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    deal.status.name.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress Bar and Percent Label
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: deal.progressFraction,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$percent%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Visual 5-Step Stepper
            _buildVisualStageStepper(deal),
            const SizedBox(height: 12),

            // Deal Meta Information Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.request_quote_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Quotation: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      Text(
                        deal.quotationNumber ?? 'Not Generated',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      if (deal.quotationAmount != null) ...[
                        const Spacer(),
                        Text(
                          currencyFmt.format(deal.quotationAmount),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ],
                  ),
                  if (deal.approverName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text('Approved By: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        Expanded(
                          child: Text(
                            '${deal.approverName}${deal.approvalDate != null ? ' (${DateFormat('dd MMM yy').format(deal.approvalDate!)})' : ''}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (deal.handledByName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('Handled By: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        Text(
                          deal.handledByName!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          'Created: ${DateFormat('dd MMM yy').format(deal.createdAt)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualStageStepper(DealProgressInfo deal) {
    final stages = [
      {'name': 'Quotation', 'index': 0},
      {'name': 'Sales Order', 'index': 1},
      {'name': 'BOQ', 'index': 2},
      {'name': 'Factory', 'index': 3},
      {'name': 'Completed', 'index': 5},
    ];

    final currentIdx = deal.currentStep.stepIndex;

    return Row(
      children: stages.asMap().entries.map((entry) {
        final item = entry.value;
        final stageIndex = item['index'] as int;
        final isCompleted = currentIdx > stageIndex || deal.progressPercent == 100;
        final isCurrent = currentIdx == stageIndex && deal.progressPercent < 100;

        Color dotColor;
        Widget innerIcon;
        if (isCompleted) {
          dotColor = AppColors.success;
          innerIcon = const Icon(Icons.check, size: 11, color: Colors.white);
        } else if (isCurrent) {
          dotColor = AppColors.primary;
          innerIcon = Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          );
        } else {
          dotColor = Colors.grey.shade300;
          innerIcon = const SizedBox.shrink();
        }

        final isLast = entry.key == stages.length - 1;

        return Expanded(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                    alignment: Alignment.center,
                    child: innerIcon,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['name'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isCurrent || isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? AppColors.primary
                          : (isCompleted ? Colors.grey.shade800 : Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? AppColors.success : Colors.grey.shade300,
                    margin: const EdgeInsets.only(bottom: 14),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------
  // STAFF INCLUDED & "WHO DID WHAT" (Item 3)
  // -------------------------------------------------------------
  Widget _buildStaffInvolvedSection(Customer360Data data) {
    final staff = data.staffContributions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_alt_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Staff Involved (${staff.length} Members)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Complete audit of who worked with this customer and the specific actions they logged.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),

        if (staff.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_off_outlined, size: 20, color: Colors.grey),
                SizedBox(width: 10),
                Text('No staff interactions logged yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
        else
          ...staff.map((s) => _buildStaffMemberCard(s)),
      ],
    );
  }

  Widget _buildStaffMemberCard(StaffMemberContribution staff) {
    final name = staff.name;
    final role = staff.role;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: staff.totalCount > 0 && staff == staff,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role,
                  style: TextStyle(fontSize: 10, color: Colors.indigo.shade800, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (staff.taskCount > 0)
                  _buildMiniChip(Icons.check_circle_outline, '${staff.taskCount} tasks', Colors.teal),
                if (staff.dealCount > 0)
                  _buildMiniChip(Icons.timeline, '${staff.dealCount} deals', Colors.blue),
                if (staff.quotationCount > 0)
                  _buildMiniChip(Icons.request_quote_outlined, '${staff.quotationCount} quotes', Colors.indigo),
                if (staff.installationCount > 0)
                  _buildMiniChip(Icons.precision_manufacturing_outlined, '${staff.installationCount} installs', Colors.cyan.shade700),
                if (staff.visitCount > 0)
                  _buildMiniChip(Icons.handyman_outlined, '${staff.visitCount} visits', Colors.orange),
                if (staff.complaintCount > 0)
                  _buildMiniChip(Icons.report_problem_outlined, '${staff.complaintCount} issues', Colors.red),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recorded Actions & Logged Work:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  ...staff.activities.map((act) => _buildActivityRow(act)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildActivityRow(StaffActivity act) {
    Color iconColor;
    IconData icon;
    switch (act.actionType) {
      case 'task':
        icon = Icons.check_circle;
        iconColor = Colors.teal;
        break;
      case 'visit':
        icon = Icons.handyman;
        iconColor = Colors.orange;
        break;
      case 'installation':
        icon = Icons.precision_manufacturing_outlined;
        iconColor = Colors.cyan.shade700;
        break;
      case 'quote':
      case 'approval':
        icon = Icons.verified;
        iconColor = Colors.indigo;
        break;
      case 'complaint':
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.lens;
        iconColor = AppColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 12, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        act.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ),
                    if (act.timestamp != null)
                      Text(
                        DateFormat('dd MMM yy').format(act.timestamp!),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                  ],
                ),
                Text(
                  act.description,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TIMELINE FEED TAB (New Feature: Unified chronological history)
  // -------------------------------------------------------------
  Widget _buildTimelineFeedTab(Customer360Data data) {
    final List<StaffActivity> allFeed = [];
    for (final s in data.staffContributions) {
      for (final a in s.activities) {
        allFeed.add(StaffActivity(
          actionType: a.actionType,
          title: '${a.title} (by ${s.name})',
          description: a.description,
          timestamp: a.timestamp,
        ));
      }
    }

    allFeed.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!);
    });

    if (allFeed.isEmpty) {
      return const Center(child: Text('No timeline interactions found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: allFeed.length,
      itemBuilder: (context, index) {
        final item = allFeed[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildActivityRow(item),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // REUSABLE UI HELPERS
  // -------------------------------------------------------------
  Widget _buildInstallationCard(dynamic inst) {
    final ticket = inst['ticket_number'] ?? _shortId(inst['id']);
    final product = inst['product_name'] ?? inst['title'] ?? 'Installation';
    final status = (inst['status'] ?? 'pending').toString();
    final tech = inst['technician_name'] ?? 'Unassigned';
    final priority = inst['priority'] ?? 'Medium';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        statusColor = AppColors.success;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        break;
      case 'assigned':
        statusColor = Colors.indigo;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          final id = inst['id']?.toString();
          if (id != null && id.isNotEmpty) {
            context.push('/installations/details/$id');
          }
        },
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.cyan.withValues(alpha: 0.1),
          child: const Icon(Icons.precision_manufacturing_outlined, size: 16, color: Colors.cyan),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Ticket #$ticket • $product',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 9.5, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: Text(
            'Tech: $tech • Priority: $priority',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String subtitle, dynamic date, IconData icon, Color color) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, size: 16, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Text(
          date != null ? DateFormat('dd MMM yy').format(DateTime.parse(date.toString())) : '-',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Customer360Data data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : () => _generatePdfReport(data),
            icon: _isGenerating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : () => _generateExcelReport(data),
            icon: _isGenerating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.table_chart),
            label: const Text('Export Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdfReport(Customer360Data data) async {
    if (_selectedCustomer == null) return;
    setState(() => _isGenerating = true);
    try {
      final bytes = await CustomerReportService.generatePdfBytes(_selectedCustomer!, data);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PdfPreviewScreen(
            pdfBytes: bytes,
            fileName: 'Customer_360_${_selectedCustomer!.companyName.replaceAll(' ', '_')}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateExcelReport(Customer360Data data) async {
    if (_selectedCustomer == null) return;
    setState(() => _isGenerating = true);
    try {
      final bytes = await CustomerReportService.generateExcelBytes(_selectedCustomer!, data);
      if (!mounted) return;

      ExportPreviewDialog.show(
        context,
        title: 'Customer 360 Report',
        fileName: 'Customer_360_${_selectedCustomer!.companyName.replaceAll(' ', '_')}.xlsx',
        headers: ['Category', 'Value'],
        rows: [
          ['Customer Name', _selectedCustomer!.companyName],
          ['Phone', _selectedCustomer!.phone ?? 'N/A'],
          ['Staff Involved', data.uniqueStaffCount.toString()],
          ['Total Pipelines', data.pipelines.length.toString()],
          ['Total Installations', data.installations.length.toString()],
          ['Total Tasks', data.tasks.length.toString()],
          ['Total Complaints', data.complaints.length.toString()],
        ],
        fileBytes: bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate Excel: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  static String _shortId(dynamic id) {
    if (id == null) return '-';
    final s = id.toString();
    return s.length > 8 ? '${s.substring(0, 8)}...' : s;
  }
}
