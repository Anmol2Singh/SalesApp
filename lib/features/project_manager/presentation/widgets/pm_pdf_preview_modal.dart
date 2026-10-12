import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../data/services/pm_pdf_service.dart';

class PmPdfPreviewModal extends StatelessWidget {
  final List<dynamic> records;
  final String companyName;
  final bool isPurchase;

  const PmPdfPreviewModal({
    super.key,
    required this.records,
    required this.companyName,
    required this.isPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final title = '${companyName.replaceAll(' ', '_')}_Directory.pdf';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.fileText, size: 20, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text(
                      'PDF Preview - ${isPurchase ? "Vendor Directory" : "Project Directory"}',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // PDF Preview Viewer with Print, Share, Download actions
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PdfPreview(
                  build: (format) => PmPdfService.generateDirectoryPdf(
                    records: records,
                    companyName: companyName,
                    isPurchase: isPurchase,
                  ),
                  initialPageFormat: PdfPageFormat.a4.landscape,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  pdfFileName: title,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
