import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/models/profile.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../models/activity_report_data.dart';

// State classes

class ReportFilter {
  final String dateRangeType; // 'today', 'week', 'month', 'custom'
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? selectedUserId;

  ReportFilter({
    this.dateRangeType = 'today',
    this.customStartDate,
    this.customEndDate,
    this.selectedUserId,
  });

  ReportFilter copyWith({
    String? dateRangeType,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? selectedUserId,
  }) {
    return ReportFilter(
      dateRangeType: dateRangeType ?? this.dateRangeType,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      selectedUserId: selectedUserId ?? this.selectedUserId,
    );
  }
}

// Providers
final allUsersProvider = FutureProvider<List<Profile>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase.from('profiles').select().order('full_name');
  return (response as List).map((json) => Profile.fromJson(json)).toList();
});

final reportFilterProvider = StateProvider<ReportFilter>((ref) {
  final profile = ref.watch(currentProfileProvider);
  return ReportFilter(selectedUserId: profile?.id);
});

final activityReportProvider = FutureProvider.autoDispose<ActivityReportData>((ref) async {
  final filter = ref.watch(reportFilterProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final userId = filter.selectedUserId;

  if (userId == null) {
    return ActivityReportData(customers: [], pipelines: [], complaints: []);
  }

  DateTime start;
  DateTime end = DateTime.now();

  switch (filter.dateRangeType) {
    case 'today':
      start = DateTime(end.year, end.month, end.day);
      break;
    case 'week':
      start = end.subtract(Duration(days: end.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
      break;
    case 'month':
      start = DateTime(end.year, end.month, 1);
      break;
    case 'custom':
      start = filter.customStartDate ?? DateTime(end.year, end.month, end.day);
      end = filter.customEndDate != null 
          ? DateTime(filter.customEndDate!.year, filter.customEndDate!.month, filter.customEndDate!.day, 23, 59, 59)
          : end;
      break;
    default:
      start = DateTime(end.year, end.month, end.day);
  }

  // Fetch Customers
  var customersQuery = supabase.from('customers').select().eq('created_by', userId).gte('created_at', start.toIso8601String()).lte('created_at', end.toIso8601String());
  // Fetch Pipelines
  var pipelinesQuery = supabase.from('sales_pipelines').select('id, customer_id, product_id, status, created_at, products(name), customers(customer_name)').eq('created_by', userId).gte('created_at', start.toIso8601String()).lte('created_at', end.toIso8601String());
  // Fetch Complaints
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> pipelines = [];
  List<Map<String, dynamic>> complaints = [];

  try {
    final cRes = await customersQuery;
    customers = List<Map<String, dynamic>>.from(cRes);
  } catch (e) {
    print("Error fetching customers for report: $e");
  }

  try {
    final pRes = await pipelinesQuery;
    pipelines = List<Map<String, dynamic>>.from(pRes);
  } catch (e) {
    print("Error fetching pipelines for report: $e");
  }

  try {
    final cmpRes = await supabase.from('complaints').select().gte('created_at', start.toIso8601String()).lte('created_at', end.toIso8601String());
    final allCmp = List<Map<String, dynamic>>.from(cmpRes);
    complaints = allCmp.where((c) => c['technician_id'] == userId || c['created_by'] == userId).toList();
  } catch (e) {
    print("Error fetching complaints for report: $e");
  }

  return ActivityReportData(customers: customers, pipelines: pipelines, complaints: complaints);
});

class UserActivityReportScreen extends ConsumerStatefulWidget {
  const UserActivityReportScreen({super.key});

  @override
  ConsumerState<UserActivityReportScreen> createState() => _UserActivityReportScreenState();
}

class _UserActivityReportScreenState extends ConsumerState<UserActivityReportScreen> {

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final filter = ref.read(reportFilterProvider);
    final initialDateRange = DateTimeRange(
      start: filter.customStartDate ?? DateTime.now(),
      end: filter.customEndDate ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.primary,
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(reportFilterProvider.notifier).state = filter.copyWith(
        dateRangeType: 'custom',
        customStartDate: picked.start,
        customEndDate: picked.end,
      );
    }
  }

  void _downloadReport(BuildContext context, ActivityReportData data) async {
    final filter = ref.read(reportFilterProvider);
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    
    String userName = profile.fullName;
    if (profile.primaryRole == UserRole.admin && filter.selectedUserId != null) {
       final usersAsync = ref.read(allUsersProvider);
       usersAsync.whenData((users) {
         final u = users.firstWhere((element) => element.id == filter.selectedUserId, orElse: () => profile);
         userName = u.fullName;
       });
    }

    try {
      final pdfBytes = await PdfService.generateActivityReportPdf(
        context: context,
        data: data,
        userName: userName,
        dateRangeType: filter.dateRangeType,
        customStartDate: filter.customStartDate,
        customEndDate: filter.customEndDate,
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: 'User_Activity_Report_${userName.replaceAll(" ", "_")}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = profile?.primaryRole == UserRole.admin;
    final filter = ref.watch(reportFilterProvider);
    final dataAsync = ref.watch(activityReportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Activity Report'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                if (isAdmin)
                  Consumer(
                    builder: (context, ref, child) {
                      final usersAsync = ref.watch(allUsersProvider);
                      return usersAsync.when(
                        data: (users) {
                          return DropdownButtonFormField<String>(
                            value: filter.selectedUserId ?? profile?.id,
                            decoration: const InputDecoration(
                              labelText: 'Select User',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: users.map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.fullName.isNotEmpty ? u.fullName : 'User (${u.id.substring(0,6)})'),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(reportFilterProvider.notifier).state = filter.copyWith(selectedUserId: val);
                              }
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading users'),
                      );
                    },
                  ),
                if (isAdmin) const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: filter.dateRangeType,
                        decoration: const InputDecoration(
                          labelText: 'Date Range',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'today', child: Text('Today')),
                          DropdownMenuItem(value: 'week', child: Text('This Week')),
                          DropdownMenuItem(value: 'month', child: Text('This Month')),
                          DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            if (val == 'custom') {
                              _selectCustomDateRange(context);
                            } else {
                              ref.read(reportFilterProvider.notifier).state = filter.copyWith(dateRangeType: val);
                            }
                          }
                        },
                      ),
                    ),
                    if (filter.dateRangeType == 'custom') ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.date_range, color: AppColors.primary),
                        onPressed: () => _selectCustomDateRange(context),
                        tooltip: 'Select Custom Dates',
                      ),
                    ]
                  ],
                ),
                if (filter.dateRangeType == 'custom' && filter.customStartDate != null && filter.customEndDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Selected: ${DateFormat('dd MMM yyyy').format(filter.customStartDate!)} - ${DateFormat('dd MMM yyyy').format(filter.customEndDate!)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: dataAsync.when(
              data: (data) {
                if (data.customers.isEmpty && data.pipelines.isEmpty && data.complaints.isEmpty) {
                  return const Center(child: Text('No activity found for the selected period.', style: TextStyle(color: AppColors.textSecondary)));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection('Customers Added (${data.customers.length})', data.customers, (c) => c['customer_name'] ?? 'Unnamed', (c) => 'ID: ${c['id']}'),
                    const SizedBox(height: 16),
                    _buildSection('Deals Created (${data.pipelines.length})', data.pipelines, 
                      (p) {
                         final customerName = p['customers'] != null ? p['customers']['customer_name'] : 'Unknown';
                         final productName = p['products'] != null ? p['products']['name'] : 'Unknown';
                         return '$customerName - $productName';
                      }, 
                      (p) => 'Pipeline ID: ${p['id']} | Status: ${p['status']}'),
                    const SizedBox(height: 16),
                    _buildSection('Complaints Handled (${data.complaints.length})', data.complaints, (c) => c['title'] ?? 'Complaint', (c) => 'Ticket: ${c['ticket_number'] ?? c['id']}'),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: dataAsync.whenOrNull(
        data: (data) => FloatingActionButton.extended(
          onPressed: () => _downloadReport(context, data),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) getTitle, String Function(Map<String, dynamic>) getSubtitle) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          child: ListTile(
            title: Text(getTitle(item), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(getSubtitle(item), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        )).toList(),
      ],
    );
  }
}
