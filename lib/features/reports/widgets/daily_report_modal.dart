// lib/features/reports/widgets/daily_report_modal.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/excel_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../screens/user_activity_report_screen.dart';

class DailyReportModal {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    final todayStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DailyReportSheet(
          userName: profile.fullName,
          userRole: profile.primaryRole.displayName,
          todayStr: todayStr,
        );
      },
    );
  }
}

class _DailyReportSheet extends ConsumerStatefulWidget {
  final String userName;
  final String userRole;
  final String todayStr;

  const _DailyReportSheet({
    required this.userName,
    required this.userRole,
    required this.todayStr,
  });

  @override
  ConsumerState<_DailyReportSheet> createState() => _DailyReportSheetState();
}

class _DailyReportSheetState extends ConsumerState<_DailyReportSheet> {
  bool _isLoading = false;
  String _loadingMessage = '';

  Future<void> _generatePdfReport() async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Generating Daily PDF Report...';
    });

    try {
      // Ensure filter is set for today for this user
      ref.read(reportFilterProvider.notifier).state = ReportFilter(
        selectedUserId: profile.id,
        dateRangeType: 'today',
      );

      final reportData = await ref.refresh(activityReportProvider.future);
      if (!mounted) return;

      final Uint8List pdfBytes = await PdfService.generateActivityReportPdf(
        context: context,
        data: reportData,
        userName: profile.fullName,
        dateRangeType: 'today',
      );

      final fileName =
          'Daily_Report_${profile.fullName.replaceAll(" ", "_")}_${DateFormat("yyyyMMdd").format(DateTime.now())}.pdf';

      if (!mounted) return;
      Navigator.pop(context); // close bottom sheet

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate daily report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportExcelReport() async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Exporting Daily Excel Report...';
    });

    try {
      ref.read(reportFilterProvider.notifier).state = ReportFilter(
        selectedUserId: profile.id,
        dateRangeType: 'today',
      );

      final reportData = await ref.refresh(activityReportProvider.future);

      if (!mounted) return;
      Navigator.pop(context); // close bottom sheet

      ExcelService.exportActivityReportExcel(
        context,
        data: reportData,
        userName: profile.fullName,
        dateStr: widget.todayStr,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export daily report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & User badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.summarize_outlined,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Activity Report',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.userName} (${widget.userRole}) • ${widget.todayStr}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_isLoading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 14),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Option 1: PDF Download
            _buildActionTile(
              icon: Icons.picture_as_pdf_outlined,
              iconColor: const Color(0xFFDC2626),
              iconBgColor: const Color(0xFFFEE2E2),
              title: "Download Today's Report (PDF)",
              subtitle: 'Generate branded PDF with summary & activities',
              badge: 'PDF',
              onTap: _generatePdfReport,
            ),
            const SizedBox(height: 10),

            // Option 2: Excel Export
            _buildActionTile(
              icon: Icons.table_chart_outlined,
              iconColor: const Color(0xFF16A34A),
              iconBgColor: const Color(0xFFDCFCE7),
              title: "Download Today's Report (Excel)",
              subtitle: 'Export detailed sheets for items, deals & logs',
              badge: 'XLSX',
              onTap: _exportExcelReport,
            ),
            const SizedBox(height: 10),

            // Option 3: View Full Activity Screen
            _buildActionTile(
              icon: Icons.visibility_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFDBEAFE),
              title: 'View & Filter Full Activity Report',
              subtitle: 'Inspect breakdown, change dates or filter details',
              badge: 'VIEW',
              onTap: () {
                Navigator.pop(context);
                context.push('/reports/activity');
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
