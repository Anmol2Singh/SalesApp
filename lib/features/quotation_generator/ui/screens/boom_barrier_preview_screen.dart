import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  late BoomBarrierProposalDraft _currentDraft;
  bool _isApproved = false;
  DateTime? _approvedAt;
  String? _approverName;

  @override
  void initState() {
    super.initState();
    _currentDraft = widget.draft;
    _isApproved = widget.draft.status.trim().toLowerCase() == 'confirmed' ||
        widget.draft.status.trim().toLowerCase() == 'approved';
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    try {
      final supabase = Supabase.instance.client;
      final qId = widget.draft.quotationId;
      if (qId.isNotEmpty) {
        final res = await supabase
            .from('quotations')
            .select('status, approved_by, approved_at, confirmed_by, confirmed_at, approver:profiles!quotations_approved_by_fkey(full_name)')
            .eq('id', qId)
            .maybeSingle();
        if (res != null) {
          final s = res['status']?.toString().toLowerCase();
          final isApp = s == 'confirmed' || s == 'approved';
          final appDate = res['approved_at'] != null
              ? DateTime.tryParse(res['approved_at'].toString())
              : (res['confirmed_at'] != null ? DateTime.tryParse(res['confirmed_at'].toString()) : null);
          final appName = res['approver'] is Map ? res['approver']['full_name']?.toString() : null;

          if (mounted) {
            setState(() {
              _isApproved = isApp;
              _approvedAt = appDate;
              _approverName = appName;
              if (isApp && _currentDraft.status.toLowerCase() != 'confirmed') {
                _currentDraft.status = 'confirmed';
                _cachedPdfBytes = null;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  String get _safePdfFileName {
    final sanitizedNumber = _currentDraft.quotationNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return 'Boom_Barrier_Quotation_$sanitizedNumber.pdf';
  }

  Future<Uint8List> _generatePdf() async {
    if (_cachedPdfBytes != null) return _cachedPdfBytes!;
    final bytes = await PdfBoomBarrierBuilder.buildQuotationPdf(
      _currentDraft,
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
              _currentDraft.customerName.isNotEmpty ? _currentDraft.customerName : 'Boom Barrier Quotation',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _currentDraft.quotationNumber,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.navBarColor,
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
      body: Column(
        children: [
          // Quotation Dates and Approver Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quotation Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        _currentDraft.quoteDate.isNotEmpty
                            ? _currentDraft.quoteDate
                            : DateFormat('dd MMM yyyy').format(_currentDraft.quotationUpdatedAt),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Approval Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        _isApproved && _approvedAt != null
                            ? DateFormat('dd MMM yyyy').format(_approvedAt!)
                            : 'Pending',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isApproved ? const Color(0xFF10B981) : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Approved By', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        _isApproved
                            ? (_approverName ?? 'Admin / Sales Head')
                            : '—',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) => _generatePdf(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: _safePdfFileName,
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: (context, build, pageFormat) async => _saveToDevice(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
