// lib/features/quotation_generator/ui/screens/quotation_preview_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/generator_quotation.dart';
import '../../models/generator_company_settings.dart';
import '../../providers/quotation_generator_providers.dart';
import '../../services/pdf_quotation_builder.dart';

class QuotationPreviewScreen extends ConsumerStatefulWidget {
  final GeneratorQuotation quotation;
  final GeneratorCompanySettings settings;

  const QuotationPreviewScreen({
    super.key,
    required this.quotation,
    required this.settings,
  });

  @override
  ConsumerState<QuotationPreviewScreen> createState() => _QuotationPreviewScreenState();
}

class _QuotationPreviewScreenState extends ConsumerState<QuotationPreviewScreen> {
  Uint8List? _cachedPdfBytes;
  bool _isSaving = false;
  bool _isSyncedToSupabase = false;

  Future<Uint8List> _generatePdf() async {
    if (_cachedPdfBytes != null) return _cachedPdfBytes!;
    final bytes = await PdfQuotationBuilder.buildQuotationPdf(
      widget.quotation,
      widget.settings,
    );
    _cachedPdfBytes = bytes;

    // Automatically sync and upload PDF to Supabase in the background
    _syncToSupabase(bytes);

    return bytes;
  }

  Future<void> _syncToSupabase(Uint8List bytes) async {
    if (_isSyncedToSupabase) return;
    try {
      await ref.read(quotationsHistoryProvider.notifier).saveQuotation(
        widget.quotation,
        pdfBytes: bytes,
      );
      if (mounted) {
        setState(() => _isSyncedToSupabase = true);
      }
    } catch (e) {
      debugPrint('Background Supabase sync error: $e');
    }
  }

  Future<void> _saveToDevice() async {
    setState(() => _isSaving = true);
    final fileName = widget.quotation.safePdfFileName;
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

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        Directory? winDownloads;
        if (userProfile != null) {
          final candidate = Directory('$userProfile\\Downloads');
          if (candidate.existsSync()) winDownloads = candidate;
        }
        winDownloads ??= await getDownloadsDirectory();
        if (winDownloads != null) {
          savedFile = File('${winDownloads.path}\\$fileName');
          await savedFile.writeAsBytes(bytes, flush: true);
          locationName = 'Downloads folder';
        }
      } else if (Platform.isAndroid) {
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (downloadDir.existsSync()) {
            savedFile = File('${downloadDir.path}/$fileName');
            await savedFile.writeAsBytes(bytes, flush: true);
            locationName = 'Downloads folder';
          }
        } catch (_) {}
      }

      if (savedFile == null) {
        final docsDir = await getApplicationDocumentsDirectory();
        savedFile = File('${docsDir.path}/$fileName');
        await savedFile.writeAsBytes(bytes, flush: true);
        locationName = 'Documents';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved to $locationName:\n$fileName'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = await _generatePdf();
      final fileName = widget.quotation.safePdfFileName;
      await Printing.sharePdf(bytes: bytes, filename: fileName);
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
            Text(
              widget.quotation.customerName.isNotEmpty ? widget.quotation.customerName : 'Quotation Preview',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(
                  _isSyncedToSupabase ? Icons.cloud_done : Icons.cloud_upload_outlined,
                  size: 12,
                  color: _isSyncedToSupabase ? Colors.greenAccent : Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSyncedToSupabase ? 'Synced to Supabase Cloud' : 'Syncing with Supabase...',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
        pdfFileName: widget.quotation.safePdfFileName,
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: (context, build, pageFormat) async => _saveToDevice(),
          ),
        ],
      ),
    );
  }
}
