import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/models/profile.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/router/app_router.dart';
import '../models/activity_report_data.dart';

// State classes

class ReportFilter {
  final String dateRangeType; // 'today', 'week', 'month', 'custom'
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? selectedUserId; // 'ALL' or user ID

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
  final List<Profile> list = [];

  try {
    final response = await supabase.from('profiles').select().order('full_name');
    final profiles = (response as List).map((json) => Profile.fromJson(json)).toList();
    list.addAll(profiles);
  } catch (_) {}

  try {
    // Also include technicians from technicians table if not already in profiles
    final techsRes = await supabase.from('technicians').select();
    for (final t in (techsRes as List? ?? [])) {
      final tId = t['id']?.toString() ?? '';
      final tName = t['name']?.toString() ?? t['full_name']?.toString() ?? '';
      final tEmail = t['email']?.toString() ?? '';
      final tPhone = t['phone']?.toString();

      // Check if already present by ID or email
      final exists = list.any((p) =>
          (tId.isNotEmpty && p.id == tId) ||
          (tEmail.isNotEmpty && p.email.toLowerCase() == tEmail.toLowerCase()));

      if (!exists && tName.isNotEmpty) {
        list.add(Profile(
          id: tId,
          fullName: tName,
          email: tEmail,
          phone: tPhone,
          roles: const [UserRole.technician],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
  } catch (_) {}

  list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
  return list;
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

  final isAll = userId == 'ALL';

  // Fetch Customers
  var customersQuery = supabase.from('customers').select('id, customer_name, phone, created_at, created_by').gte('created_at', start.toIso8601String()).lte('created_at', end.toIso8601String());
  if (!isAll) {
    customersQuery = customersQuery.eq('created_by', userId);
  }

  // Fetch Pipelines
  var pipelinesQuery = supabase.from('sales_pipelines').select('id, customer_id, product_id, status, created_at, created_by, products(name), customers(customer_name)').gte('created_at', start.toIso8601String()).lte('created_at', end.toIso8601String());
  if (!isAll) {
    pipelinesQuery = pipelinesQuery.eq('created_by', userId);
  }

  // Fetch Complaints
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> pipelines = [];
  List<Map<String, dynamic>> complaints = [];
  List<Map<String, dynamic>> stepAuditLogs = [];
  List<Map<String, dynamic>> communications = [];
  List<Map<String, dynamic>> leads = [];
  List<Map<String, dynamic>> prospects = [];
  List<Map<String, dynamic>> conversions = [];

  try {
    final cRes = await customersQuery;
    customers = List<Map<String, dynamic>>.from(cRes);
  } catch (e) {
    debugPrint("Error fetching customers for report: $e");
  }

  try {
    final pRes = await pipelinesQuery;
    pipelines = List<Map<String, dynamic>>.from(pRes);
  } catch (e) {
    debugPrint("Error fetching pipelines for report: $e");
  }

  try {
    final cmpRes = await supabase.from('complaints').select('id, ticket_number, title, customer_name, status, created_at, created_by, technician_id').gte('created_at', start.toIso8601String()).lte('created_at', end.toIso8601String());
    final allCmp = List<Map<String, dynamic>>.from(cmpRes);
    if (isAll) {
      complaints = allCmp;
    } else {
      complaints = allCmp.where((c) => c['technician_id'] == userId || c['created_by'] == userId).toList();
    }
  } catch (e) {
    debugPrint("Error fetching complaints for report: $e");
  }

  // Fetch Deal Steps Finished / Updated (step_audit_log)
  try {
    var stepsQuery = supabase
        .from('step_audit_log')
        .select('id, pipeline_id, step_name, action, performed_by, performed_at, notes, sales_pipelines(customers(customer_name), products(name))')
        .gte('performed_at', start.toIso8601String())
        .lte('performed_at', end.toIso8601String());
    if (!isAll) {
      stepsQuery = stepsQuery.eq('performed_by', userId);
    }
    final sRes = await stepsQuery.order('performed_at', ascending: false);
    stepAuditLogs = List<Map<String, dynamic>>.from(sRes);
  } catch (e) {
    debugPrint("Error fetching step_audit_log for report: $e");
    try {
      var stepsFallback = supabase
          .from('step_audit_log')
          .select('id, pipeline_id, step_name, action, performed_by, performed_at, notes')
          .gte('performed_at', start.toIso8601String())
          .lte('performed_at', end.toIso8601String());
      if (!isAll) {
        stepsFallback = stepsFallback.eq('performed_by', userId);
      }
      final sResFallback = await stepsFallback.order('performed_at', ascending: false);
      stepAuditLogs = List<Map<String, dynamic>>.from(sResFallback);
    } catch (_) {}
  }

  // Fetch CRM Communications Logged
  try {
    var commsQuery = supabase
        .from('crm_communications')
        .select('id, lead_id, type, summary, logged_by, created_at, crm_leads(prospect_name, product_name)')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    if (!isAll) {
      commsQuery = commsQuery.eq('logged_by', userId);
    }
    final commRes = await commsQuery.order('created_at', ascending: false);
    communications = List<Map<String, dynamic>>.from(commRes);
  } catch (e) {
    debugPrint("Error fetching crm_communications for report: $e");
    try {
      var commsFallback = supabase
          .from('crm_communications')
          .select('id, lead_id, type, summary, logged_by, created_at')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());
      if (!isAll) {
        commsFallback = commsFallback.eq('logged_by', userId);
      }
      final commResFallback = await commsFallback.order('created_at', ascending: false);
      communications = List<Map<String, dynamic>>.from(commResFallback);
    } catch (_) {}
  }

  // Fetch Leads Added
  try {
    var leadsQuery = supabase
        .from('crm_leads')
        .select('id, prospect_id, prospect_name, product_name, estimated_value, status, created_by, created_at, converted_to_customer_id, converted_by, updated_at')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    if (!isAll) {
      leadsQuery = leadsQuery.eq('created_by', userId);
    }
    final lRes = await leadsQuery.order('created_at', ascending: false);
    leads = List<Map<String, dynamic>>.from(lRes);
  } catch (e) {
    debugPrint("Error fetching crm_leads for report: $e");
  }

  // Fetch Prospects Added
  try {
    var prQuery = supabase
        .from('crm_prospects')
        .select('id, name, phone, company, source, created_by, created_at, converted_to_lead_id')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    if (!isAll) {
      prQuery = prQuery.eq('created_by', userId);
    }
    final prRes = await prQuery.order('created_at', ascending: false);
    prospects = List<Map<String, dynamic>>.from(prRes);
  } catch (e) {
    debugPrint("Error fetching crm_prospects for report: $e");
  }

  // Fetch Conversions (Prospect -> Lead & Lead -> Customer/Deal)
  try {
    for (final l in leads) {
      if (l['prospect_id'] != null) {
        conversions.add({
          'type': 'Prospect -> Lead',
          'name': l['prospect_name'] ?? 'Prospect',
          'details': '${l['product_name'] ?? 'Lead'} (Est. ₹${l['estimated_value'] ?? 0})',
          'time': l['created_at'],
          'user_id': l['created_by'],
        });
      }
    }
    var convQuery = supabase
        .from('crm_leads')
        .select('id, prospect_name, product_name, estimated_value, converted_to_customer_id, converted_by, updated_at')
        .not('converted_to_customer_id', 'is', null)
        .gte('updated_at', start.toIso8601String())
        .lte('updated_at', end.toIso8601String());
    if (!isAll) {
      convQuery = convQuery.eq('converted_by', userId);
    }
    final convRes = await convQuery;
    for (final cl in (convRes as List)) {
      conversions.add({
        'type': 'Lead -> Customer/Deal',
        'name': cl['prospect_name'] ?? 'Customer',
        'details': 'Product: ${cl['product_name'] ?? '-'} | Value: ₹${cl['estimated_value'] ?? 0}',
        'time': cl['updated_at'],
        'user_id': cl['converted_by'],
      });
    }
  } catch (e) {
    debugPrint("Error fetching conversions for report: $e");
  }

  return ActivityReportData(
    customers: customers,
    pipelines: pipelines,
    complaints: complaints,
    stepAuditLogs: stepAuditLogs,
    communications: communications,
    leads: leads,
    prospects: prospects,
    conversions: conversions,
  );
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

    final isAll = filter.selectedUserId == 'ALL';

    try {
      Uint8List pdfBytes;
      String fileName;

      final isSalesHead = profile.primaryRole == UserRole.salesHead || profile.roles.contains(UserRole.salesHead);
      final isAdmin = profile.primaryRole == UserRole.admin || profile.roles.contains(UserRole.admin);

      if (isAll) {
        final usersAsync = ref.read(allUsersProvider);
        final rawUsers = (usersAsync.valueOrNull ?? [])
            .where((u) => u.primaryRole != UserRole.customer)
            .toList();

        final users = (isSalesHead && !isAdmin
                ? rawUsers.where((u) =>
                    u.primaryRole == UserRole.sales ||
                    u.primaryRole == UserRole.salesHead ||
                    u.roles.contains(UserRole.sales) ||
                    u.roles.contains(UserRole.salesHead))
                : rawUsers)
            .toList()
          ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

        final userEntries = users.map((u) {
          final uCustomers = data.customers.where((c) => c['created_by'] == u.id).toList();
          final uPipelines = data.pipelines.where((p) => p['created_by'] == u.id).toList();
          final uComplaints = data.complaints.where((c) => c['technician_id'] == u.id || c['created_by'] == u.id).toList();
          final uStepLogs = data.stepAuditLogs.where((s) => s['performed_by'] == u.id).toList();
          final uComms = data.communications.where((c) => c['logged_by'] == u.id).toList();
          final uLeads = data.leads.where((l) => l['created_by'] == u.id).toList();
          final uProspects = data.prospects.where((p) => p['created_by'] == u.id).toList();
          final uConversions = data.conversions.where((c) => c['user_id'] == u.id).toList();

          return {
            'userName': u.fullName.isNotEmpty ? u.fullName : 'User (${u.id.substring(0, 6)})',
            'userRole': u.primaryRole.displayName,
            'data': ActivityReportData(
              customers: uCustomers,
              pipelines: uPipelines,
              complaints: uComplaints,
              stepAuditLogs: uStepLogs,
              communications: uComms,
              leads: uLeads,
              prospects: uProspects,
              conversions: uConversions,
            ),
          };
        }).toList();

        pdfBytes = await PdfService.generateAllUsersActivityReportPdf(
          context: context,
          userEntries: userEntries,
          dateRangeType: filter.dateRangeType,
          customStartDate: filter.customStartDate,
          customEndDate: filter.customEndDate,
        );
        fileName = isSalesHead
            ? 'Sales_Executives_Activity_Report_${DateFormat("yyyyMMdd").format(DateTime.now())}.pdf'
            : 'All_Users_Activity_Report_${DateFormat("yyyyMMdd").format(DateTime.now())}.pdf';
      } else {
        String userName = profile.fullName;
        if ((isAdmin || isSalesHead) && filter.selectedUserId != null) {
          final usersAsync = ref.read(allUsersProvider);
          usersAsync.whenData((users) {
            final u = users.firstWhere((element) => element.id == filter.selectedUserId, orElse: () => profile);
            userName = u.fullName;
          });
        }

        pdfBytes = await PdfService.generateActivityReportPdf(
          context: context,
          data: data,
          userName: userName,
          dateRangeType: filter.dateRangeType,
          customStartDate: filter.customStartDate,
          customEndDate: filter.customEndDate,
        );
        fileName = 'User_Activity_Report_${userName.replaceAll(" ", "_")}.pdf';
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: fileName,
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

  void _showUserSearchPicker(
    BuildContext context,
    List<Profile> users,
    String? currentUserId, {
    bool isSalesHead = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (pickerCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            // For sales head: only sales executives and sales head
            final eligibleUsers = users.where((u) {
              if (u.primaryRole == UserRole.customer) return false;
              if (isSalesHead) {
                return u.primaryRole == UserRole.sales ||
                    u.primaryRole == UserRole.salesHead ||
                    u.roles.contains(UserRole.sales) ||
                    u.roles.contains(UserRole.salesHead);
              }
              return true;
            }).toList()
              ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

            final filteredUsers = eligibleUsers.where((u) {
              final query = searchQuery.trim().toLowerCase();
              if (query.isEmpty) return true;
              final nameMatch = u.fullName.toLowerCase().contains(query);
              final roleMatch = u.primaryRole.displayName.toLowerCase().contains(query);
              final emailMatch = u.email.toLowerCase().contains(query);
              return nameMatch || roleMatch || emailMatch;
            }).toList();

            final isAllSelected = currentUserId == 'ALL';
            final allOptionTitle = isSalesHead ? 'All Sales Executives' : 'All Users (All Staff)';
            final allOptionSubtitle = isSalesHead
                ? 'Generate consolidated report for all sales executives'
                : 'Generate complete report with each user on a new page';

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isSalesHead ? 'Select Sales Person' : 'Select User for Report',
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(pickerCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: isSalesHead ? 'Search sales executive by name...' : 'Search user by name or role...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setPickerState(() => searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setPickerState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  // "All Users" / "All Sales Executives" Option
                  if (searchQuery.trim().isEmpty ||
                      'all'.contains(searchQuery.trim().toLowerCase()) ||
                      allOptionTitle.toLowerCase().contains(searchQuery.trim().toLowerCase())) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: isAllSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAllSelected ? AppColors.primary : Colors.grey.shade300,
                          width: isAllSelected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAllSelected ? AppColors.primary : Colors.grey.shade200,
                          child: Icon(Icons.groups_outlined, color: isAllSelected ? Colors.white : AppColors.primary),
                        ),
                        title: Text(
                          allOptionTitle,
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          allOptionSubtitle,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: isAllSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                        onTap: () {
                          final filter = ref.read(reportFilterProvider);
                          ref.read(reportFilterProvider.notifier).state = filter.copyWith(selectedUserId: 'ALL');
                          Navigator.pop(pickerCtx);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                  ],
                  const SizedBox(height: 4),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              'No users found matching "$searchQuery"',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final u = filteredUsers[idx];
                              final isSelected = currentUserId == u.id;
                              final initials = u.fullName.isNotEmpty
                                  ? u.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                  : 'U';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  u.fullName.isNotEmpty ? u.fullName : 'User (${u.id.substring(0, 6)})',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${u.primaryRole.displayName}${u.email.isNotEmpty ? " • ${u.email}" : ""}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                                ),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                                onTap: () {
                                  final filter = ref.read(reportFilterProvider);
                                  ref.read(reportFilterProvider.notifier).state = filter.copyWith(selectedUserId: u.id);
                                  Navigator.pop(pickerCtx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = profile?.primaryRole == UserRole.admin || (profile?.roles.contains(UserRole.admin) ?? false);
    final isSalesHead = profile?.primaryRole == UserRole.salesHead || (profile?.roles.contains(UserRole.salesHead) ?? false);
    final canSelectUser = isAdmin || isSalesHead;
    final filter = ref.watch(reportFilterProvider);
    final dataAsync = ref.watch(activityReportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else if (isAdmin) {
              context.go(AppRoutes.adminDashboard);
            } else {
              context.go(AppRoutes.salesDashboard);
            }
          },
        ),
        title: const Text("Today's Report"),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                if (canSelectUser)
                  Consumer(
                    builder: (context, ref, child) {
                      final usersAsync = ref.watch(allUsersProvider);
                      return usersAsync.when(
                        data: (users) {
                          String selectedUserDisplay = isSalesHead ? 'Select Sales Person' : 'Select User';
                          if (filter.selectedUserId == 'ALL') {
                            selectedUserDisplay = isSalesHead ? 'All Sales Executives' : 'All Users (All Staff)';
                          } else if (filter.selectedUserId != null) {
                            final found = users.where((u) => u.id == filter.selectedUserId).toList();
                            if (found.isNotEmpty) {
                              selectedUserDisplay = '${found.first.fullName} (${found.first.primaryRole.displayName})';
                            }
                          }

                          return InkWell(
                            onTap: () => _showUserSearchPicker(
                              context,
                              users,
                              filter.selectedUserId,
                              isSalesHead: isSalesHead && !isAdmin,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    filter.selectedUserId == 'ALL' ? Icons.groups_outlined : Icons.person_outline,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isSalesHead && !isAdmin ? 'Sales Executive' : 'Report User',
                                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          selectedUserDisplay,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading users'),
                      );
                    },
                  ),
                if (canSelectUser) const SizedBox(height: 16),
                
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
                final isEmpty = data.customers.isEmpty &&
                    data.pipelines.isEmpty &&
                    data.complaints.isEmpty &&
                    data.stepAuditLogs.isEmpty &&
                    data.communications.isEmpty &&
                    data.leads.isEmpty &&
                    data.prospects.isEmpty &&
                    data.conversions.isEmpty;

                if (isEmpty) {
                  return const Center(child: Text('No activity found for the selected period.', style: TextStyle(color: AppColors.textSecondary)));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection('Customers Added (${data.customers.length})', data.customers, (c) => c['customer_name'] ?? 'Unnamed', (c) => 'Phone: ${c['phone'] ?? '-'} | ID: ${c['id']}'),
                    const SizedBox(height: 16),
                    _buildSection('Deals Created (${data.pipelines.length})', data.pipelines, 
                      (p) {
                         final customerName = p['customers'] != null ? p['customers']['customer_name'] : 'Unknown';
                         final productName = p['products'] != null ? p['products']['name'] : 'Unknown';
                         return '$customerName - $productName';
                      }, 
                      (p) => 'Pipeline ID: ${p['id']} | Status: ${p['status']}'),
                    const SizedBox(height: 16),
                    _buildSection('Deal Steps Finished / Updated (${data.stepAuditLogs.length})', data.stepAuditLogs,
                      (s) {
                        final pipeline = s['sales_pipelines'] as Map<String, dynamic>?;
                        final cust = pipeline?['customers'] as Map<String, dynamic>?;
                        final prod = pipeline?['products'] as Map<String, dynamic>?;
                        final cName = cust?['customer_name'] ?? '';
                        final pName = prod?['name'] ?? '';
                        final dealTitle = [cName, pName].where((e) => e.isNotEmpty).join(' - ');
                        final stepTitle = s['step_name']?.toString().toUpperCase() ?? 'STEP';
                        return dealTitle.isNotEmpty ? '$dealTitle • $stepTitle' : 'Step: $stepTitle';
                      },
                      (s) {
                        final action = s['action'] ?? 'updated';
                        final notes = s['notes'] != null && s['notes'].toString().isNotEmpty ? ' | ${s['notes']}' : '';
                        final time = s['performed_at'] != null ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(s['performed_at']) ?? DateTime.now()) : '';
                        return 'Action: $action$notes | $time';
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSection('Lead Communication Logs (${data.communications.length})', data.communications,
                      (comm) {
                        final lead = comm['crm_leads'] as Map<String, dynamic>?;
                        final leadName = lead?['prospect_name'] ?? 'Lead';
                        final type = comm['type'] ?? 'Log';
                        return '$leadName • $type';
                      },
                      (comm) {
                        final summary = comm['summary'] ?? '-';
                        final time = comm['created_at'] != null ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(comm['created_at']) ?? DateTime.now()) : '';
                        return '$summary | $time';
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSection('Leads Added (${data.leads.length})', data.leads,
                      (l) => '${l['prospect_name'] ?? 'Lead'} - ${l['product_name'] ?? ''}',
                      (l) => 'Est. Value: ₹${l['estimated_value'] ?? 0} | Status: ${l['status'] ?? 'New'}',
                    ),
                    const SizedBox(height: 16),
                    _buildSection('Prospects Added (${data.prospects.length})', data.prospects,
                      (pr) => pr['name'] ?? 'Prospect',
                      (pr) => 'Phone: ${pr['phone'] ?? '-'} | Source: ${pr['source'] ?? '-'}',
                    ),
                    const SizedBox(height: 16),
                    _buildSection('Conversions (${data.conversions.length})', data.conversions,
                      (conv) => '${conv['type']}: ${conv['name']}',
                      (conv) {
                        final time = conv['time'] != null ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(conv['time']) ?? DateTime.now()) : '';
                        return '${conv['details']} | $time';
                      },
                    ),
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
        )),
      ],
    );
  }
}
