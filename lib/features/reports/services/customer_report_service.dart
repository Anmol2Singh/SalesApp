// lib/features/reports/services/customer_report_service.dart

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import '../../../core/models/customer.dart';

/// Represents a single recorded action or milestone handled by a staff member.
class StaffActivity {
  final String actionType; // 'task', 'deal', 'quote', 'approval', 'visit', 'complaint', 'account', 'installation'
  final String title;
  final String description;
  final DateTime? timestamp;

  const StaffActivity({
    required this.actionType,
    required this.title,
    required this.description,
    this.timestamp,
  });
}

/// Aggregated summary of a staff member's contributions for a specific customer.
class StaffMemberContribution {
  final String name;
  final String role;
  final List<StaffActivity> activities;

  StaffMemberContribution({
    required this.name,
    required this.role,
    required this.activities,
  });

  int get taskCount => activities.where((a) => a.actionType == 'task').length;
  int get dealCount => activities.where((a) => a.actionType == 'deal').length;
  int get visitCount => activities.where((a) => a.actionType == 'visit').length;
  int get quotationCount => activities.where((a) => a.actionType == 'quote' || a.actionType == 'approval').length;
  int get complaintCount => activities.where((a) => a.actionType == 'complaint').length;
  int get installationCount => activities.where((a) => a.actionType == 'installation').length;
  int get totalCount => activities.length;
}

/// Rich progress information for a customer's sales deal / pipeline.
class DealProgressInfo {
  final String pipelineId;
  final String productName;
  final PipelineStep currentStep;
  final PipelineStatus status;
  final double progressFraction; // 0.0 to 1.0
  final int progressPercent; // 0 to 100
  final String stageDisplayName;
  final DateTime createdAt;
  final String? quotationNumber;
  final double? quotationAmount;
  final String? quotationStatus;
  final String? approverName;
  final DateTime? approvalDate;
  final String? handledByName;

  const DealProgressInfo({
    required this.pipelineId,
    required this.productName,
    required this.currentStep,
    required this.status,
    required this.progressFraction,
    required this.progressPercent,
    required this.stageDisplayName,
    required this.createdAt,
    this.quotationNumber,
    this.quotationAmount,
    this.quotationStatus,
    this.approverName,
    this.approvalDate,
    this.handledByName,
  });
}

/// Complete 360-Degree customer data package.
class Customer360Data {
  final List pipelines;
  final List tasks;
  final List complaints;
  final List serviceVisits;
  final List installations;
  final List quotations;
  final List leads;
  final List<StaffMemberContribution> staffContributions;
  final List<DealProgressInfo> dealProgressList;

  Customer360Data({
    required this.pipelines,
    required this.tasks,
    required this.complaints,
    required this.serviceVisits,
    this.installations = const [],
    this.quotations = const [],
    this.leads = const [],
    this.staffContributions = const [],
    this.dealProgressList = const [],
  });

  int get uniqueStaffCount => staffContributions.length;

  double get totalQuotedValue {
    double sum = 0;
    for (final q in quotations) {
      final val = (q['grand_total'] as num?)?.toDouble() ?? 0;
      sum += val;
    }
    return sum;
  }

  double get totalApprovedValue {
    double sum = 0;
    for (final q in quotations) {
      final s = (q['status'] ?? '').toString().toLowerCase();
      if (s == 'confirmed' || s == 'approved') {
        sum += (q['grand_total'] as num?)?.toDouble() ?? 0;
      }
    }
    return sum;
  }
}

class CustomerReportService {
  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');
  static final _shortDateFormat = DateFormat('dd MMM yyyy');
  static final _indianCurrencyFormat = NumberFormat('#,##,##0', 'en_IN');

  /// Formats any numeric value into Indian comma-separated format: e.g. 19,89,126 or 47,200.
  static String formatIndianCurrency(num? value) {
    if (value == null) return '0';
    return _indianCurrencyFormat.format(value);
  }

  /// Sanitizes text for PDF generation: prevents rectangle box `.notdef` tofu glyphs
  /// by replacing unsupported Unicode characters (₹, •, ·) with standard ASCII equivalents.
  static String cleanPdfText(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('₹', 'Rs. ')
        .replaceAll('•', '-')
        .replaceAll('·', '-');
  }

  static Future<Customer360Data> fetchCustomerData(
    SupabaseClient supabase,
    Customer customer,
  ) async {
    // 1. Fetch Pipelines
    List pipelinesList = [];
    try {
      final pipelinesRes = await supabase
          .from('sales_pipelines')
          .select('''
            *,
            products(name),
            profiles!sales_pipelines_created_by_fkey(id, full_name, role),
            quotations(*),
            sales_orders(id, status),
            boqs(id, status),
            factory_orders(id, status),
            purchase_orders(id, status)
          ''')
          .eq('customer_id', customer.id)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      pipelinesList = pipelinesRes as List;
    } catch (_) {
      try {
        final pipelinesRes = await supabase
            .from('sales_pipelines')
            .select('*, products(name)')
            .eq('customer_id', customer.id)
            .order('created_at', ascending: false);
        pipelinesList = pipelinesRes as List;
      } catch (_) {}
    }

    // 2. Fetch Tasks
    List tasksList = [];
    try {
      final tasksRes = await supabase
          .from('daily_tasks')
          .select('*')
          .eq('customer_id', customer.id)
          .order('completed_at', ascending: false);
      tasksList = tasksRes as List;
    } catch (_) {}

    // 3. Fetch Complaints
    List complaintsList = [];
    try {
      final complaintsRes = await supabase
          .from('complaints')
          .select('*')
          .eq('customer_id', customer.id)
          .order('created_at', ascending: false);
      complaintsList = complaintsRes as List;
    } catch (_) {}

    // 4. Fetch Service Visits
    List serviceVisitsList = [];
    try {
      final serviceVisitsRes = await supabase
          .from('service_visits')
          .select('*')
          .eq('customer_id', customer.id)
          .order('scheduled_date', ascending: false);
      serviceVisitsList = serviceVisitsRes as List;
    } catch (_) {}

    // 5. Fetch Installation Reports
    List installationsList = [];
    try {
      var query = supabase.from('installations').select('*');
      if (customer.phone != null && customer.phone!.trim().isNotEmpty) {
        query = query.or('customer_id.eq.${customer.id},customer_phone.eq.${customer.phone!.trim()}');
      } else {
        query = query.eq('customer_id', customer.id);
      }
      final installationsRes = await query.order('created_at', ascending: false);
      installationsList = installationsRes as List;
    } catch (_) {}

    // 6. Fetch Quotations (by pipeline IDs and by customer phone/name)
    List quotationsList = [];
    try {
      final pipelineIds = pipelinesList.map((p) => p['id']?.toString()).whereType<String>().toList();
      if (pipelineIds.isNotEmpty) {
        final quotesRes = await supabase
            .from('quotations')
            .select('*')
            .inFilter('pipeline_id', pipelineIds)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false);
        quotationsList = quotesRes as List;
      }

      if (customer.phone != null && customer.phone!.trim().isNotEmpty) {
        final directPhoneQuotes = await supabase
            .from('quotations')
            .select('*')
            .eq('customer_phone', customer.phone!.trim())
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false);
        final existingIds = quotationsList.map((q) => q['id']?.toString()).toSet();
        for (final dq in (directPhoneQuotes as List)) {
          final id = dq['id']?.toString();
          if (id != null && !existingIds.contains(id)) {
            quotationsList.add(dq);
            existingIds.add(id);
          }
        }
      }
    } catch (_) {}

    // 7. Fetch linked CRM Leads
    List leadsList = [];
    try {
      var query = supabase.from('crm_leads').select('*');
      if (customer.phone != null && customer.phone!.trim().isNotEmpty) {
        query = query.or('converted_to_customer_id.eq.${customer.id},phone.eq.${customer.phone!.trim()}');
      } else {
        query = query.eq('converted_to_customer_id', customer.id);
      }
      final leadsRes = await query.order('created_at', ascending: false);
      leadsList = leadsRes as List;
    } catch (_) {}

    // 8. Aggregate Staff Contributions ("Who Did What")
    final Map<String, StaffMemberContribution> staffMap = {};

    void addActivity({
      required String? rawName,
      required String defaultRole,
      required String actionType,
      required String title,
      required String description,
      dynamic rawTimestamp,
    }) {
      if (rawName == null) return;
      final cleanName = rawName.trim();
      if (cleanName.isEmpty ||
          cleanName == '-' ||
          cleanName.toLowerCase() == 'n/a' ||
          cleanName.toLowerCase() == 'system' ||
          cleanName.toLowerCase() == 'unknown') {
        return;
      }

      DateTime? parsedTime;
      if (rawTimestamp != null) {
        if (rawTimestamp is DateTime) {
          parsedTime = rawTimestamp;
        } else {
          parsedTime = DateTime.tryParse(rawTimestamp.toString());
        }
      }

      final key = cleanName.toLowerCase();
      final activity = StaffActivity(
        actionType: actionType,
        title: title,
        description: description,
        timestamp: parsedTime,
      );

      final existing = staffMap[key];
      if (existing == null) {
        staffMap[key] = StaffMemberContribution(
          name: cleanName,
          role: defaultRole,
          activities: [activity],
        );
      } else {
        String effectiveRole = existing.role;
        if ((effectiveRole == 'Staff' || effectiveRole.isEmpty) && defaultRole != 'Staff') {
          effectiveRole = defaultRole;
        }
        existing.activities.add(activity);
        staffMap[key] = StaffMemberContribution(
          name: existing.name,
          role: effectiveRole,
          activities: existing.activities,
        );
      }
    }

    // Customer Account Assignments
    if (customer.salesmanName != null && customer.salesmanName!.isNotEmpty) {
      addActivity(
        rawName: customer.salesmanName,
        defaultRole: 'Sales Representative',
        actionType: 'account',
        title: 'Assigned Sales Rep',
        description: 'Designated primary sales representative for ${customer.companyName}',
        rawTimestamp: customer.createdAt,
      );
    }
    if (customer.assignedToName != null && customer.assignedToName!.isNotEmpty) {
      addActivity(
        rawName: customer.assignedToName,
        defaultRole: 'Account Manager',
        actionType: 'account',
        title: 'Customer Account Manager',
        description: 'Assigned as account manager for ${customer.companyName}',
        rawTimestamp: customer.createdAt,
      );
    }
    if (customer.convertedByName != null && customer.convertedByName!.isNotEmpty) {
      addActivity(
        rawName: customer.convertedByName,
        defaultRole: 'Sales Rep',
        actionType: 'account',
        title: 'Converted Lead to Customer',
        description: 'Successfully onboarded lead into customer base',
        rawTimestamp: customer.createdAt,
      );
    }

    // Daily Tasks
    for (final t in tasksList) {
      final staffName = t['user_name']?.toString();
      final role = t['user_role']?.toString() ?? 'Sales Executive';
      final desc = t['task_description']?.toString() ?? 'Daily task logged';
      addActivity(
        rawName: staffName,
        defaultRole: role,
        actionType: 'task',
        title: 'Task Completed',
        description: desc,
        rawTimestamp: t['completed_at'] ?? t['created_at'],
      );
    }

    // Installation Reports
    for (final inst in installationsList) {
      final tech = inst['technician_name']?.toString();
      final ticket = inst['ticket_number']?.toString() ?? _shortId(inst['id']);
      final product = inst['product_name']?.toString() ?? inst['title']?.toString() ?? 'Installation';
      final status = (inst['status'] ?? 'pending').toString().toUpperCase();
      final notes = inst['notes']?.toString() ?? inst['description']?.toString() ?? '';
      addActivity(
        rawName: tech,
        defaultRole: 'Installation Technician',
        actionType: 'installation',
        title: 'Installation #$ticket: $product',
        description: 'Status: $status${notes.isNotEmpty ? ' • $notes' : ''}',
        rawTimestamp: inst['created_at'],
      );
    }

    // Service Visits
    for (final v in serviceVisitsList) {
      final techName = v['technician_name']?.toString();
      final status = v['status']?.toString() ?? 'Visit';
      final notes = v['notes']?.toString();
      final desc = notes != null && notes.isNotEmpty
          ? 'Status: $status • $notes'
          : 'Service visit scheduled ($status)';
      addActivity(
        rawName: techName,
        defaultRole: 'Technician',
        actionType: 'visit',
        title: 'Service Visit ($status)',
        description: desc,
        rawTimestamp: v['scheduled_date'] ?? v['created_at'],
      );
    }

    // Complaints
    for (final c in complaintsList) {
      final tech = c['technician_name']?.toString() ?? c['assigned_to']?.toString();
      final ticket = c['ticket_number']?.toString() ?? _shortId(c['id']);
      final type = c['complaint_type']?.toString() ?? 'Issue';
      final desc = c['description']?.toString() ?? 'Complaint logged';
      addActivity(
        rawName: tech,
        defaultRole: 'Support Specialist',
        actionType: 'complaint',
        title: 'Complaint Ticket $ticket',
        description: '$type: $desc (Status: ${c['status'] ?? '-'})',
        rawTimestamp: c['created_at'],
      );
    }

    // Sales Pipelines
    for (final p in pipelinesList) {
      final profile = p['profiles'];
      String? creatorName;
      String creatorRole = 'Sales Executive';
      if (profile is Map) {
        creatorName = profile['full_name']?.toString();
        if (profile['role'] != null) {
          creatorRole = profile['role'].toString();
        }
      }
      final productName = p['products']?['name']?.toString() ?? 'Deal';
      final step = (p['current_step'] ?? 'quotation').toString().replaceAll('_', ' ').toUpperCase();
      addActivity(
        rawName: creatorName,
        defaultRole: creatorRole,
        actionType: 'deal',
        title: 'Created Sales Deal: $productName',
        description: 'Initiated deal pipeline in stage $step (Status: ${p['status'] ?? '-'})',
        rawTimestamp: p['created_at'],
      );
    }

    // Quotations
    for (final q in quotationsList) {
      final salesman = q['salesman']?.toString();
      final qNum = q['quotation_number']?.toString() ?? 'Quote';
      final totalVal = (q['grand_total'] as num?)?.toDouble() ?? 0.0;
      final formattedTotal = 'Rs. ${formatIndianCurrency(totalVal)}';
      
      addActivity(
        rawName: salesman,
        defaultRole: 'Sales Representative',
        actionType: 'quote',
        title: 'Prepared Quotation $qNum',
        description: 'Quoted total of $formattedTotal (Status: ${q['status'] ?? '-'})',
        rawTimestamp: q['created_at'],
      );

      final approver = q['approver_name']?.toString();
      if (approver != null && approver.trim().isNotEmpty) {
        addActivity(
          rawName: approver,
          defaultRole: 'Approving Manager',
          actionType: 'approval',
          title: 'Approved Quotation $qNum',
          description: 'Officially approved quote amount of $formattedTotal',
          rawTimestamp: q['approved_at'] ?? q['updated_at'],
        );
      }
    }

    // Leads
    for (final l in leadsList) {
      final assigned = l['assigned_to_name']?.toString();
      final created = l['created_by_name']?.toString();
      final leadName = l['company']?.toString() ?? l['contact_person']?.toString() ?? 'Lead inquiry';
      
      addActivity(
        rawName: assigned,
        defaultRole: 'Sales Representative',
        actionType: 'deal',
        title: 'Managed Lead: $leadName',
        description: 'Handled customer inquiry and qualification phase',
        rawTimestamp: l['created_at'],
      );
      if (created != null && created != assigned) {
        addActivity(
          rawName: created,
          defaultRole: 'Lead Generator',
          actionType: 'deal',
          title: 'Captured Initial Lead: $leadName',
          description: 'Source: ${l['source'] ?? 'Direct'}',
          rawTimestamp: l['created_at'],
        );
      }
    }

    // Sort activities for each staff member, newest first
    final staffList = staffMap.values.toList();
    for (final sm in staffList) {
      sm.activities.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });
    }
    // Sort staff list so the most active staff member is on top
    staffList.sort((a, b) => b.activities.length.compareTo(a.activities.length));

    // 9. Calculate Customer Deal Progress Information
    final List<DealProgressInfo> dealProgress = [];
    for (final p in pipelinesList) {
      final pipelineId = p['id']?.toString() ?? '';
      final productName = p['products']?['name']?.toString() ?? 'Product Deal';
      final step = PipelineStep.fromString(p['current_step']?.toString() ?? 'quotation');
      final status = PipelineStatus.fromString(p['status']?.toString() ?? 'in_progress');

      // Find quote for this pipeline
      Map<String, dynamic>? quoteData;
      if (p['quotations'] != null) {
        if (p['quotations'] is List && (p['quotations'] as List).isNotEmpty) {
          quoteData = Map<String, dynamic>.from((p['quotations'] as List).first as Map);
        } else if (p['quotations'] is Map) {
          quoteData = Map<String, dynamic>.from(p['quotations'] as Map);
        }
      }
      if (quoteData == null) {
        for (final q in quotationsList) {
          if (q['pipeline_id']?.toString() == pipelineId) {
            quoteData = Map<String, dynamic>.from(q as Map);
            break;
          }
        }
      }

      // Progress fraction and percentage computation
      double progressFraction;
      int progressPercent;
      if (status == PipelineStatus.completed) {
        progressFraction = 1.0;
        progressPercent = 100;
      } else if (status == PipelineStatus.cancelled) {
        progressFraction = 0.0;
        progressPercent = 0;
      } else {
        switch (step) {
          case PipelineStep.quotation:
            final isConfirmed = quoteData != null &&
                ((quoteData['status'] ?? '').toString().toLowerCase() == 'confirmed' ||
                    quoteData['approved_at'] != null);
            progressFraction = isConfirmed ? 0.25 : 0.15;
            progressPercent = isConfirmed ? 25 : 15;
            break;
          case PipelineStep.salesOrder:
            progressFraction = 0.40;
            progressPercent = 40;
            break;
          case PipelineStep.boq:
            progressFraction = 0.60;
            progressPercent = 60;
            break;
          case PipelineStep.factoryOrder:
            progressFraction = 0.80;
            progressPercent = 80;
            break;
          case PipelineStep.purchaseOrder:
            progressFraction = 0.90;
            progressPercent = 90;
            break;
          case PipelineStep.completed:
            progressFraction = 1.0;
            progressPercent = 100;
            break;
        }
      }

      DateTime? approvalDt;
      if (quoteData?['approved_at'] != null) {
        approvalDt = DateTime.tryParse(quoteData!['approved_at'].toString());
      }

      dealProgress.add(DealProgressInfo(
        pipelineId: pipelineId,
        productName: productName,
        currentStep: step,
        status: status,
        progressFraction: progressFraction,
        progressPercent: progressPercent,
        stageDisplayName: step.displayName,
        createdAt: DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now(),
        quotationNumber: quoteData?['quotation_number']?.toString(),
        quotationAmount: (quoteData?['grand_total'] as num?)?.toDouble(),
        quotationStatus: quoteData?['status']?.toString(),
        approverName: quoteData?['approver_name']?.toString(),
        approvalDate: approvalDt,
        handledByName: p['profiles']?['full_name']?.toString(),
      ));
    }

    return Customer360Data(
      pipelines: pipelinesList,
      tasks: tasksList,
      complaints: complaintsList,
      serviceVisits: serviceVisitsList,
      installations: installationsList,
      quotations: quotationsList,
      leads: leadsList,
      staffContributions: staffList,
      dealProgressList: dealProgress,
    );
  }

  static Future<Uint8List> generatePdfBytes(
    Customer customer,
    Customer360Data data,
  ) async {
    final pipelines = data.pipelines;
    final tasks = data.tasks;
    final complaints = data.complaints;
    final serviceVisits = data.serviceVisits;
    final installations = data.installations;
    final staffContributions = data.staffContributions;
    final dealProgress = data.dealProgressList;

    pw.Font regularFont;
    pw.Font boldFont;
    try {
      regularFont = await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 3));
      boldFont = await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 3));
    } catch (_) {
      regularFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }
    final pdfTheme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            // Header
            pw.Header(
              level: 0,
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Customer 360-Degree Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.Text(_shortDateFormat.format(DateTime.now()), style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Customer Info Box
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(cleanPdfText(customer.companyName), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Contact: ${cleanPdfText(customer.contactPerson ?? "N/A")}', style: const pw.TextStyle(fontSize: 10.5)),
                            pw.SizedBox(height: 3),
                            pw.Text('Phone: ${cleanPdfText(customer.phone ?? "N/A")}', style: const pw.TextStyle(fontSize: 10.5)),
                            pw.SizedBox(height: 3),
                            pw.Text('Email: ${cleanPdfText(customer.email ?? "N/A")}', style: const pw.TextStyle(fontSize: 10.5)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Address: ${cleanPdfText(customer.address ?? "N/A")}', style: const pw.TextStyle(fontSize: 10.5)),
                            pw.SizedBox(height: 3),
                            if (customer.gstNumber != null && customer.gstNumber!.isNotEmpty)
                              pw.Text('GSTIN: ${cleanPdfText(customer.gstNumber)}', style: const pw.TextStyle(fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Summary Stats Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildStatBox('Staff Included', staffContributions.length.toString(), PdfColors.indigo700),
                _buildStatBox('Deals', pipelines.length.toString(), PdfColors.blue700),
                _buildStatBox('Tasks Logged', tasks.length.toString(), PdfColors.green700),
                _buildStatBox('Installations', installations.length.toString(), PdfColors.cyan700),
                _buildStatBox('Visits', serviceVisits.length.toString(), PdfColors.orange700),
                _buildStatBox('Complaints', complaints.length.toString(), PdfColors.red700),
              ],
            ),
            pw.SizedBox(height: 22),

            // SECTION 1: Staff Included & "Who Did What"
            pw.Text(
              'Staff Involved & Contributions (${staffContributions.length} Members)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
            ),
            pw.SizedBox(height: 6),
            if (staffContributions.isEmpty)
              pw.Text('No staff interactions recorded yet.', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Staff Name', 'Role', 'Actions', 'Who Did What (Key Contributions)'],
                data: staffContributions.map((s) {
                  final recentSummary = s.activities
                      .take(3)
                      .map((a) => '- ${a.title}: ${cleanPdfText(a.description)}')
                      .join('\n');
                  return [
                    cleanPdfText(s.name),
                    cleanPdfText(s.role),
                    '${s.totalCount} logged',
                    recentSummary.isNotEmpty ? recentSummary : 'Associated with customer account',
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 22),

            // SECTION 2: Customer Deal Progress
            if (dealProgress.isNotEmpty) ...[
              pw.Text(
                'Customer Deal Progress (${dealProgress.length} Deals)',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Product', 'Current Stage', 'Progress', 'Quotation #', 'Amount (INR)', 'Approved By / Date'],
                data: dealProgress.map((d) {
                  final amtText = d.quotationAmount != null
                      ? 'Rs. ${formatIndianCurrency(d.quotationAmount)}'
                      : '-';
                  final approvalText = d.approverName != null
                      ? '${cleanPdfText(d.approverName)}${d.approvalDate != null ? ' (${_shortDateFormat.format(d.approvalDate!)})' : ''}'
                      : (d.quotationStatus != null ? cleanPdfText(d.quotationStatus!) : '-');
                  return [
                    cleanPdfText(d.productName),
                    cleanPdfText(d.stageDisplayName),
                    '${d.progressPercent}%',
                    cleanPdfText(d.quotationNumber ?? '-'),
                    amtText,
                    approvalText,
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 22),
            ],

            // SECTION 3: Installation Reports
            if (installations.isNotEmpty) ...[
              pw.Text(
                'Installation Reports (${installations.length})',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Ticket #', 'Product', 'Technician', 'Status', 'Priority', 'Logged On'],
                data: installations.map((inst) => [
                  cleanPdfText(inst['ticket_number'] ?? _shortId(inst['id'])),
                  cleanPdfText(inst['product_name'] ?? inst['title'] ?? '-'),
                  cleanPdfText(inst['technician_name'] ?? 'Unassigned'),
                  cleanPdfText((inst['status'] ?? '-').toString().toUpperCase()),
                  cleanPdfText(inst['priority'] ?? '-'),
                  _formatDate(inst['created_at']),
                ]).toList(),
              ),
              pw.SizedBox(height: 22),
            ],

            // SECTION 4: Daily Tasks Completed
            if (tasks.isNotEmpty) ...[
              pw.Text('Daily Tasks Completed', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Sr.', 'Task Description', 'Staff Member', 'Completed At'],
                data: tasks.asMap().entries.map((entry) => [
                  (entry.key + 1).toString(),
                  cleanPdfText(entry.value['task_description'] ?? '-'),
                  cleanPdfText(entry.value['user_name'] ?? '-'),
                  _formatDate(entry.value['completed_at']),
                ]).toList(),
              ),
              pw.SizedBox(height: 22),
            ],

            // SECTION 5: Service Visits
            if (serviceVisits.isNotEmpty) ...[
              pw.Text('Service Visits', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange700),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Sr.', 'Status', 'Technician', 'Notes', 'Scheduled Date'],
                data: serviceVisits.asMap().entries.map((entry) => [
                  (entry.key + 1).toString(),
                  cleanPdfText(entry.value['status'] ?? '-'),
                  cleanPdfText(entry.value['technician_name'] ?? '-'),
                  cleanPdfText(entry.value['notes'] ?? '-'),
                  _formatDate(entry.value['scheduled_date']),
                ]).toList(),
              ),
              pw.SizedBox(height: 22),
            ],

            // SECTION 6: Complaints
            if (complaints.isNotEmpty) ...[
              pw.Text('Customer Complaints', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Ticket', 'Status', 'Priority', 'Type', 'Description', 'Logged On'],
                data: complaints.map((c) => [
                  cleanPdfText(c['ticket_number'] ?? _shortId(c['id'])),
                  cleanPdfText(c['status'] ?? '-'),
                  cleanPdfText(c['priority'] ?? '-'),
                  cleanPdfText(c['complaint_type'] ?? '-'),
                  cleanPdfText(c['description'] ?? '-'),
                  _formatDate(c['created_at']),
                ]).toList(),
              ),
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static Future<List<int>> generateExcelBytes(
    Customer customer,
    Customer360Data data,
  ) async {
    final pipelines = data.pipelines;
    final tasks = data.tasks;
    final complaints = data.complaints;
    final serviceVisits = data.serviceVisits;
    final installations = data.installations;
    final staffContributions = data.staffContributions;
    final dealProgress = data.dealProgressList;

    final excel = Excel.createExcel();
    
    // 1. Summary Sheet
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('Customer 360-Degree Report')]);
    summarySheet.appendRow([TextCellValue('Generated On: ${DateFormat('dd MMM yyyy').format(DateTime.now())}')]);
    summarySheet.appendRow([TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Customer Name'), TextCellValue(customer.companyName)]);
    summarySheet.appendRow([TextCellValue('Contact Person'), TextCellValue(customer.contactPerson ?? 'N/A')]);
    summarySheet.appendRow([TextCellValue('Phone'), TextCellValue(customer.phone ?? 'N/A')]);
    summarySheet.appendRow([TextCellValue('Email'), TextCellValue(customer.email ?? 'N/A')]);
    summarySheet.appendRow([TextCellValue('Address'), TextCellValue(customer.address ?? 'N/A')]);
    summarySheet.appendRow([TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Staff Members Included'), TextCellValue(staffContributions.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Quoted Value (INR)'), TextCellValue(formatIndianCurrency(data.totalQuotedValue))]);
    summarySheet.appendRow([TextCellValue('Total Approved Value (INR)'), TextCellValue(formatIndianCurrency(data.totalApprovedValue))]);
    summarySheet.appendRow([TextCellValue('Total Deals / Pipelines'), TextCellValue(pipelines.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Installations'), TextCellValue(installations.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Daily Tasks'), TextCellValue(tasks.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Service Visits'), TextCellValue(serviceVisits.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Complaints'), TextCellValue(complaints.length.toString())]);

    // 2. Staff Contributions Sheet ("Who Did What")
    final staffSheet = excel['Staff Contributions'];
    staffSheet.appendRow([
      TextCellValue('Staff Name'),
      TextCellValue('Role'),
      TextCellValue('Action Type'),
      TextCellValue('Title'),
      TextCellValue('Description'),
      TextCellValue('Timestamp'),
    ]);
    for (final s in staffContributions) {
      for (final a in s.activities) {
        staffSheet.appendRow([
          TextCellValue(s.name),
          TextCellValue(s.role),
          TextCellValue(a.actionType.toUpperCase()),
          TextCellValue(a.title),
          TextCellValue(cleanPdfText(a.description)),
          TextCellValue(a.timestamp != null ? _dateFormat.format(a.timestamp!) : '-'),
        ]);
      }
    }

    // 3. Deal Progress Sheet
    final dpSheet = excel['Deal Progress'];
    dpSheet.appendRow([
      TextCellValue('Deal ID'),
      TextCellValue('Product'),
      TextCellValue('Current Stage'),
      TextCellValue('Progress %'),
      TextCellValue('Status'),
      TextCellValue('Quotation No'),
      TextCellValue('Quotation Value (INR)'),
      TextCellValue('Approved By'),
      TextCellValue('Approval Date'),
      TextCellValue('Created At'),
    ]);
    for (final dp in dealProgress) {
      dpSheet.appendRow([
        TextCellValue(_shortId(dp.pipelineId)),
        TextCellValue(dp.productName),
        TextCellValue(dp.stageDisplayName),
        TextCellValue('${dp.progressPercent}%'),
        TextCellValue(dp.status.name.toUpperCase()),
        TextCellValue(dp.quotationNumber ?? '-'),
        TextCellValue(dp.quotationAmount != null ? formatIndianCurrency(dp.quotationAmount) : '-'),
        TextCellValue(dp.approverName ?? '-'),
        TextCellValue(dp.approvalDate != null ? _shortDateFormat.format(dp.approvalDate!) : '-'),
        TextCellValue(_formatDate(dp.createdAt)),
      ]);
    }

    // 4. Installations Sheet
    final instSheet = excel['Installations'];
    instSheet.appendRow([
      TextCellValue('Ticket #'),
      TextCellValue('Product'),
      TextCellValue('Technician'),
      TextCellValue('Status'),
      TextCellValue('Priority'),
      TextCellValue('Notes'),
      TextCellValue('Created At'),
    ]);
    for (final inst in installations) {
      instSheet.appendRow([
        TextCellValue(inst['ticket_number'] ?? _shortId(inst['id'])),
        TextCellValue(inst['product_name'] ?? inst['title'] ?? '-'),
        TextCellValue(inst['technician_name'] ?? 'Unassigned'),
        TextCellValue((inst['status'] ?? '-').toString().toUpperCase()),
        TextCellValue(inst['priority'] ?? '-'),
        TextCellValue(inst['notes'] ?? inst['description'] ?? '-'),
        TextCellValue(_formatDate(inst['created_at'])),
      ]);
    }

    // 5. Tasks Sheet
    final tSheet = excel['Tasks'];
    tSheet.appendRow([TextCellValue('Task'), TextCellValue('Staff Member'), TextCellValue('Completed At')]);
    for (final t in tasks) {
      tSheet.appendRow([
        TextCellValue(t['task_description'] ?? '-'),
        TextCellValue(t['user_name'] ?? '-'),
        TextCellValue(_formatDate(t['completed_at'])),
      ]);
    }

    // 6. Service Visits Sheet
    final svSheet = excel['Service Visits'];
    svSheet.appendRow([TextCellValue('ID'), TextCellValue('Status'), TextCellValue('Technician'), TextCellValue('Notes'), TextCellValue('Scheduled For')]);
    for (final v in serviceVisits) {
      svSheet.appendRow([
        TextCellValue(_shortId(v['id'])),
        TextCellValue(v['status'] ?? '-'),
        TextCellValue(v['technician_name'] ?? '-'),
        TextCellValue(v['notes'] ?? '-'),
        TextCellValue(_formatDate(v['scheduled_date'])),
      ]);
    }

    // 7. Complaints Sheet
    final cSheet = excel['Complaints'];
    cSheet.appendRow([TextCellValue('Ticket'), TextCellValue('Status'), TextCellValue('Priority'), TextCellValue('Type'), TextCellValue('Description'), TextCellValue('Created At')]);
    for (final c in complaints) {
      cSheet.appendRow([
        TextCellValue(c['ticket_number'] ?? _shortId(c['id'])),
        TextCellValue(c['status'] ?? '-'),
        TextCellValue(c['priority'] ?? '-'),
        TextCellValue(c['complaint_type'] ?? '-'),
        TextCellValue(c['description'] ?? '-'),
        TextCellValue(_formatDate(c['created_at'])),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel file');

    return bytes;
  }

  static pw.Widget _buildStatBox(String title, String value, PdfColor color) {
    return pw.Container(
      width: 78,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(title, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.white)),
        ],
      ),
    );
  }

  static String _shortId(dynamic id) {
    if (id == null) return '-';
    final s = id.toString();
    return s.length > 8 ? '${s.substring(0, 8)}...' : s;
  }

  static String _formatDate(dynamic dateString) {
    if (dateString == null) return '-';
    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) return '-';
    return _dateFormat.format(dt.toLocal());
  }
}
