import 'dart:typed_data';
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

  if (!isAdmin && !isSalesHead) {
    return [];
  }

  final response = await supabase
      .from('customers')
      .select('*')
      .order('company_name', ascending: true);

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
  bool _isGenerating = false;

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
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Customer for Report',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Customer>(
                      isExpanded: true,
                      hint: const Text('Choose a customer...'),
                      value: _selectedCustomer,
                      items: customers.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text('${c.companyName} (${c.phone ?? "No Phone"})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCustomer = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_selectedCustomer != null)
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
              ...data.pipelines.map((p) => _buildDataCard(p['products']?['name'] ?? 'Pipeline', p['status'] ?? '-', p['created_at'])).toList(),
              if (data.pipelines.isEmpty) const Text('No pipelines found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Tasks (${data.tasks.length})', Icons.task),
              ...data.tasks.map((t) => _buildDataCard(t['task_description'] ?? 'Task', t['user_name'] ?? '-', t['completed_at'])).toList(),
              if (data.tasks.isEmpty) const Text('No tasks found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Complaints (${data.complaints.length})', Icons.report_problem),
              ...data.complaints.map((c) => _buildDataCard(c['ticket_number'] ?? 'Complaint', c['status'] ?? '-', c['created_at'])).toList(),
              if (data.complaints.isEmpty) const Text('No complaints found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Service Visits (${data.serviceVisits.length})', Icons.handyman),
              ...data.serviceVisits.map((s) => _buildDataCard(s['technician_name'] ?? 'Visit', s['status'] ?? '-', s['scheduled_date'])).toList(),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
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
