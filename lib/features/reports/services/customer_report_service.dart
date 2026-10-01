import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../../../core/models/customer.dart';

class Customer360Data {
  final List pipelines;
  final List tasks;
  final List complaints;
  final List serviceVisits;

  Customer360Data({
    required this.pipelines,
    required this.tasks,
    required this.complaints,
    required this.serviceVisits,
  });
}

class CustomerReportService {
  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  static Future<Customer360Data> fetchCustomerData(
    SupabaseClient supabase,
    Customer customer,
  ) async {
    final pipelinesRes = await supabase.from('sales_pipelines').select('*, products(name)').eq('customer_id', customer.id);
    final tasksRes = await supabase.from('daily_tasks').select('*').eq('customer_id', customer.id);
    final complaintsRes = await supabase.from('complaints').select('*').eq('customer_id', customer.id);
    final serviceVisitsRes = await supabase.from('service_visits').select('*').eq('customer_id', customer.id);

    return Customer360Data(
      pipelines: pipelinesRes as List,
      tasks: tasksRes as List,
      complaints: complaintsRes as List,
      serviceVisits: serviceVisitsRes as List,
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

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey),
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
                  pw.Text('Customer 360-Degree Report', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Customer Info Box
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(customer.companyName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Contact: ${customer.contactPerson ?? "N/A"}', style: const pw.TextStyle(fontSize: 12)),
                            pw.SizedBox(height: 4),
                            pw.Text('Phone: ${customer.phone ?? "N/A"}', style: const pw.TextStyle(fontSize: 12)),
                            pw.SizedBox(height: 4),
                            pw.Text('Email: ${customer.email ?? "N/A"}', style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Address: ${customer.address ?? "N/A"}', style: const pw.TextStyle(fontSize: 12)),
                            pw.SizedBox(height: 4),
                            if (customer.gstNumber != null && customer.gstNumber!.isNotEmpty)
                              pw.Text('GSTIN: ${customer.gstNumber}', style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary Stats
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox('Pipelines', pipelines.length.toString(), PdfColors.blue700),
                _buildStatBox('Tasks', tasks.length.toString(), PdfColors.green700),
                _buildStatBox('Complaints', complaints.length.toString(), PdfColors.red700),
                _buildStatBox('Visits', serviceVisits.length.toString(), PdfColors.orange700),
              ],
            ),
            pw.SizedBox(height: 30),

            // Pipelines Section
            if (pipelines.isNotEmpty) ...[
              pw.Text('Sales Pipelines', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo400),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Sr. No.', 'ID', 'Product', 'Status', 'Step', 'Created At'],
                data: pipelines.asMap().entries.map((entry) => [
                  (entry.key + 1).toString(),
                  _shortId(entry.value['id']),
                  entry.value['products']?['name'] ?? 'N/A',
                  entry.value['status'] ?? '-',
                  (entry.value['current_step'] ?? '-').toString().replaceAll('_', ' ').toUpperCase(),
                  _formatDate(entry.value['created_at']),
                ]).toList(),
              ),
              pw.SizedBox(height: 24),
            ],

            // Complaints Section
            if (complaints.isNotEmpty) ...[
              pw.Text('Complaints', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Sr. No.', 'Ticket', 'Status', 'Priority', 'Type', 'Created At'],
                data: complaints.asMap().entries.map((entry) => [
                  (entry.key + 1).toString(),
                  entry.value['ticket_number'] ?? _shortId(entry.value['id']),
                  entry.value['status'] ?? '-',
                  entry.value['priority'] ?? '-',
                  entry.value['complaint_type'] ?? '-',
                  _formatDate(entry.value['created_at']),
                ]).toList(),
              ),
              pw.SizedBox(height: 24),
            ],

            // Service Visits Section
            if (serviceVisits.isNotEmpty) ...[
              pw.Text('Service Visits', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Sr. No.', 'ID', 'Status', 'Technician', 'Scheduled For'],
                data: serviceVisits.asMap().entries.map((entry) => [
                  (entry.key + 1).toString(),
                  _shortId(entry.value['id']),
                  entry.value['status'] ?? '-',
                  entry.value['technician_name'] ?? '-',
                  _formatDate(entry.value['scheduled_date']),
                ]).toList(),
              ),
              pw.SizedBox(height: 24),
            ],

            // Daily Tasks Section
            if (tasks.isNotEmpty) ...[
              pw.Text('Daily Tasks', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Sr. No.', 'Task', 'Staff', 'Completed At'],
                data: tasks.asMap().entries.map((entry) => [
                  (entry.key + 1).toString(),
                  entry.value['task_description'] ?? '-',
                  entry.value['user_name'] ?? '-',
                  _formatDate(entry.value['completed_at']),
                ]).toList(),
              ),
              pw.SizedBox(height: 24),
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

    final excel = Excel.createExcel();
    
    // Summary Sheet
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
    summarySheet.appendRow([TextCellValue('Total Pipelines'), TextCellValue(pipelines.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Complaints'), TextCellValue(complaints.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Service Visits'), TextCellValue(serviceVisits.length.toString())]);
    summarySheet.appendRow([TextCellValue('Total Tasks'), TextCellValue(tasks.length.toString())]);

    // Pipelines Sheet
    final pSheet = excel['Pipelines'];
    pSheet.appendRow([TextCellValue('ID'), TextCellValue('Product'), TextCellValue('Status'), TextCellValue('Step'), TextCellValue('Created At')]);
    for (final p in pipelines) {
      pSheet.appendRow([
        TextCellValue(_shortId(p['id'])),
        TextCellValue(p['products']?['name'] ?? 'N/A'),
        TextCellValue(p['status'] ?? '-'),
        TextCellValue(p['current_step'] ?? '-'),
        TextCellValue(_formatDate(p['created_at'])),
      ]);
    }

    // Complaints Sheet
    final cSheet = excel['Complaints'];
    cSheet.appendRow([TextCellValue('Ticket'), TextCellValue('Status'), TextCellValue('Priority'), TextCellValue('Type'), TextCellValue('Created At')]);
    for (final c in complaints) {
      cSheet.appendRow([
        TextCellValue(c['ticket_number'] ?? _shortId(c['id'])),
        TextCellValue(c['status'] ?? '-'),
        TextCellValue(c['priority'] ?? '-'),
        TextCellValue(c['complaint_type'] ?? '-'),
        TextCellValue(_formatDate(c['created_at'])),
      ]);
    }

    // Service Visits Sheet
    final svSheet = excel['Service Visits'];
    svSheet.appendRow([TextCellValue('ID'), TextCellValue('Status'), TextCellValue('Technician'), TextCellValue('Scheduled For')]);
    for (final v in serviceVisits) {
      svSheet.appendRow([
        TextCellValue(_shortId(v['id'])),
        TextCellValue(v['status'] ?? '-'),
        TextCellValue(v['technician_name'] ?? '-'),
        TextCellValue(_formatDate(v['scheduled_date'])),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel file');

    return bytes;
  }

  static pw.Widget _buildStatBox(String title, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 4),
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
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
