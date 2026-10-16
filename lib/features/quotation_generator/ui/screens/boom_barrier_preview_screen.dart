// lib/features/quotation_generator/ui/screens/boom_barrier_preview_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/boom_barrier_proposal_draft.dart';
import '../../models/qg_product_profile.dart';
import '../../services/pdf_boom_barrier_builder.dart';

class BoomBarrierPreviewScreen extends StatefulWidget {
  final BoomBarrierProposalDraft draft;
  final QgProductProfile profile;

  const BoomBarrierPreviewScreen({
    super.key,
    required this.draft,
    required this.profile,
  });

  @override
  State<BoomBarrierPreviewScreen> createState() => _BoomBarrierPreviewScreenState();
}

class _BoomBarrierPreviewScreenState extends State<BoomBarrierPreviewScreen> {
  Uint8List? _cachedPdfBytes;
  bool _isSaving = false;

  String get _safePdfFileName {
    final sanitizedNumber = widget.draft.quotationNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return 'Boom_Barrier_Quotation_$sanitizedNumber.pdf';
  }

  Future<Uint8List> _generatePdf() async {
    if (_cachedPdfBytes != null) return _cachedPdfBytes!;
    final bytes = await PdfBoomBarrierBuilder.buildQuotationPdf(
      widget.draft,
      widget.profile,
    );
    _cachedPdfBytes = bytes;
    return bytes;
  }

  Future<void> _saveToDevice() async {
    setState(() => _isSaving = true);
    final fileName = _safePdfFileName;
    try {
      final bytes = await _generatePdf();

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ Saved: $fileName'), backgroundColor: AppColors.success),
          );
        }
        return;
      }

      File? savedFile;
      String locationName = 'Downloads';

      try {
        Directory? targetDir;
        if (Platform.isAndroid) {
          targetDir = Directory('/storage/emulated/0/Download');
          if (!await targetDir.exists()) {
            targetDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          targetDir = await getDownloadsDirectory();
        } else if (Platform.isIOS) {
          targetDir = await getApplicationDocumentsDirectory();
          locationName = 'Documents';
        }

        if (targetDir != null && await targetDir.exists()) {
          final filePath = '${targetDir.path}/$fileName';
          savedFile = File(filePath);
          await savedFile.writeAsBytes(bytes);
        }
      } catch (_) {
        savedFile = null;
      }

      if (savedFile == null) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opened share dialog to save PDF'), backgroundColor: AppColors.primary),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Saved to $locationName: $fileName'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = await _generatePdf();
      await Printing.sharePdf(bytes: bytes, filename: _safePdfFileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = widget.draft.status.toLowerCase() == 'confirmed';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.draft.quotationNumber,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isConfirmed ? Colors.green.shade700 : Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isConfirmed ? 'CONFIRMED' : 'DRAFT',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            Text(
              widget.draft.customerName,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Save to Device',
            onPressed: _isSaving ? null : _saveToDevice,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: _safePdfFileName,
      ),
    );
  }
}
