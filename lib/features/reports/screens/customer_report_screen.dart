import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/customer_report_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/widgets/export_preview_dialog.dart';

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

  final response = await supabase
      .from('customers')
      .select('*')
      .order('customer_name', ascending: true);

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersForReportProvider);
    final dataAsync = ref.watch(customer360DataProvider(_selectedCustomer));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer 360 Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
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
                  const SizedBox(height: 16),
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              _buildCustomerInfoCard(),
              const SizedBox(height: 16),
              _buildStatsRow(data),
              const SizedBox(height: 24),
              _buildSectionTitle('Sales Pipelines (${data.pipelines.length})', Icons.timeline),
              ...data.pipelines.map((p) => _buildDataCard(p['products']?['name'] ?? 'Pipeline', p['status'] ?? '-', p['created_at'])),
              if (data.pipelines.isEmpty) const Text('No pipelines found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Tasks (${data.tasks.length})', Icons.task),
              ...data.tasks.map((t) => _buildDataCard(t['task_description'] ?? 'Task', t['user_name'] ?? '-', t['completed_at'])),
              if (data.tasks.isEmpty) const Text('No tasks found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Complaints (${data.complaints.length})', Icons.report_problem),
              ...data.complaints.map((c) => _buildDataCard(c['ticket_number'] ?? 'Complaint', c['status'] ?? '-', c['created_at'])),
              if (data.complaints.isEmpty) const Text('No complaints found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Service Visits (${data.serviceVisits.length})', Icons.handyman),
              ...data.serviceVisits.map((s) => _buildDataCard(s['technician_name'] ?? 'Visit', s['status'] ?? '-', s['scheduled_date'])),
              if (data.serviceVisits.isEmpty) const Text('No service visits found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButtons(data),
      ],
    );
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedCustomer!.companyName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Contact: ${_selectedCustomer!.contactPerson ?? "N/A"}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Phone: ${_selectedCustomer!.phone ?? "N/A"}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Email: ${_selectedCustomer!.email ?? "N/A"}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('Address: ${_selectedCustomer!.address ?? "N/A"}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(Customer360Data data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Pipelines', data.pipelines.length.toString(), Colors.blue),
        _buildStatItem('Tasks', data.tasks.length.toString(), Colors.green),
        _buildStatItem('Complaints', data.complaints.length.toString(), Colors.red),
        _buildStatItem('Visits', data.serviceVisits.length.toString(), Colors.orange),
      ],
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String subtitle, dynamic date) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        trailing: Text(date != null ? DateFormat('dd MMM yy').format(DateTime.parse(date.toString())) : '-', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ),
    );
  }

  Widget _buildActionButtons(Customer360Data data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : () => _generatePdfReport(data),
            icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : () => _generateExcelReport(data),
            icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.table_chart),
            label: const Text('Export Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
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
      
      // Navigate to PDF Preview Screen
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
          ['Total Pipelines', data.pipelines.length.toString()],
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
}
